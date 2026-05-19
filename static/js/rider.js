/**
 * rider.js - All rider page logic with map integration
 * Depends on: api.js, Leaflet
 */

// Global map variables
let deliveryMap = null;
let pickupMarker = null;
let deliveryMarker = null;
let routeLine = null;
let currentDeliveryId = null;
let allMarkers = []; // Array to store all markers for multi-order view
let allRoutes = []; // Array to store all route lines for multi-order view
let isMultiOrderView = false; // Flag to track if showing multiple orders

// -- Helpers ---------------------------------------------------
function formatDate(iso) {
    if (!iso) return '-';
    return new Date(iso).toLocaleDateString('en-PH', {
        year: 'numeric', month: 'short', day: 'numeric'
    });
}

function formatCurrency(amount) {
    return '₱' + Number(amount || 0).toLocaleString('en-PH', { minimumFractionDigits: 2 });
}

function showToast(msg, isError = false) {
    const t = document.getElementById('toast');
    if (!t) return;
    t.textContent = msg;
    t.style.background = isError ? '#c0392b' : '#1a1a3e';
    t.classList.add('show');
    setTimeout(() => t.classList.remove('show'), 3000);
}

// -- Sidebar mobile toggle -------------------------------------
document.addEventListener('DOMContentLoaded', () => {
    const toggle  = document.getElementById('sidebarToggle');
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (toggle && sidebar) {
        toggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
            if (overlay) overlay.style.display =
                sidebar.classList.contains('open') ? 'block' : 'none';
        });
    }
    if (overlay) {
        overlay.addEventListener('click', () => {
            sidebar?.classList.remove('open');
            overlay.style.display = 'none';
        });
    }

    if (document.getElementById('deliveriesTable')) {
        loadDeliveries();
        initializeMap();
    }
    if (document.getElementById('riderRecentDeliveries')) {
        loadRiderDashboard();
        loadAvailability();
        loadNotifications();
        loadPerformance();
    }
    if (document.getElementById('totalEarnings')) loadEarnings();
    if (document.getElementById('profileForm'))   loadProfile();

    // Close notif panel on outside click
    document.addEventListener('click', e => {
        const panel = document.getElementById('notifPanel');
        const bell  = document.getElementById('notifBell');
        if (panel && !panel.contains(e.target) && bell && !bell.contains(e.target))
            panel.style.display = 'none';
    });
});

// -- Map Integration -------------------------------------------
function initializeMap() {
    const mapElement = document.getElementById('deliveryMap');
    if (!mapElement || typeof L === 'undefined') return;

    // Initialize map centered on Philippines
    deliveryMap = L.map('deliveryMap').setView([12.8797, 121.7740], 6);
    
    // Add OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19
    }).addTo(deliveryMap);
}

function showDeliveryRoute(orderId) {
    if (!deliveryMap) {
        initializeMap();
        if (!deliveryMap) return;
    }

    currentDeliveryId = orderId;
    const mapContainer = document.getElementById('mapContainer');
    const mapTitle = document.getElementById('mapTitle');
    
    mapContainer.style.display = 'block';
    mapTitle.textContent = `Delivery Route - Order #${orderId.slice(0, 8)}`;

    // Clear existing markers and route
    if (pickupMarker) deliveryMap.removeLayer(pickupMarker);
    if (deliveryMarker) deliveryMap.removeLayer(deliveryMarker);
    if (routeLine) deliveryMap.removeLayer(routeLine);

    // Fetch location data
    API.rider.getLocations(orderId)
        .then(data => {
            const pickup = data.pickup_location;
            const delivery = data.delivery_location;

            // Update address displays
            document.getElementById('pickupAddress').textContent = pickup.formatted_address;
            document.getElementById('deliveryAddress').textContent = delivery.formatted_address;

            // Add markers if coordinates are available
            if (pickup.latitude && pickup.longitude) {
                pickupMarker = L.marker([pickup.latitude, pickup.longitude], {
                    icon: L.divIcon({
                        className: 'custom-marker pickup-marker-icon',
                        html: '<div style="background:#007bff;color:white;border-radius:50%;width:30px;height:30px;display:flex;align-items:center;justify-content:center;font-size:16px;border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.3)">&#128230;</div>',
                        iconSize: [30, 30],
                        iconAnchor: [15, 15]
                    })
                }).addTo(deliveryMap);
                
                pickupMarker.bindPopup(`
                    <div style="text-align:center;">
                        <strong>&#128230; Pickup Location</strong><br>
                        <small>${pickup.formatted_address}</small>
                    </div>
                `);
            }

            if (delivery.latitude && delivery.longitude) {
                deliveryMarker = L.marker([delivery.latitude, delivery.longitude], {
                    icon: L.divIcon({
                        className: 'custom-marker delivery-marker-icon',
                        html: '<div style="background:#dc3545;color:white;border-radius:50%;width:30px;height:30px;display:flex;align-items:center;justify-content:center;font-size:16px;border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.3)">&#127919;</div>',
                        iconSize: [30, 30],
                        iconAnchor: [15, 15]
                    })
                }).addTo(deliveryMap);
                
                deliveryMarker.bindPopup(`
                    <div style="text-align:center;">
                        <strong>&#127919; Delivery Location</strong><br>
                        <small>${delivery.formatted_address}</small>
                    </div>
                `);
            }

            // Draw route and calculate distance if both coordinates exist
            if (pickup.latitude && pickup.longitude && delivery.latitude && delivery.longitude) {
                const pickupLatLng = [pickup.latitude, pickup.longitude];
                const deliveryLatLng = [delivery.latitude, delivery.longitude];
                
                // Draw route line
                routeLine = L.polyline([pickupLatLng, deliveryLatLng], {
                    color: '#28a745',
                    weight: 4,
                    opacity: 0.7,
                    dashArray: '10, 10'
                }).addTo(deliveryMap);
                
                // Calculate and display distance
                const distance = calculateDistance(pickup.latitude, pickup.longitude, delivery.latitude, delivery.longitude);
                document.getElementById('routeDistance').textContent = `Distance: ${distance.toFixed(2)} km`;
                
                // Fit map to show both markers
                const group = new L.featureGroup([pickupMarker, deliveryMarker]);
                deliveryMap.fitBounds(group.getBounds().pad(0.1));
            } else {
                // If coordinates missing, show message
                let missingInfo = [];
                if (!pickup.latitude || !pickup.longitude) missingInfo.push('pickup location');
                if (!delivery.latitude || !delivery.longitude) missingInfo.push('delivery location');
                
                document.getElementById('routeDistance').textContent = `Missing coordinates for ${missingInfo.join(' and ')}`;
                
                // Center on available location or default
                if (pickup.latitude && pickup.longitude) {
                    deliveryMap.setView([pickup.latitude, pickup.longitude], 15);
                } else if (delivery.latitude && delivery.longitude) {
                    deliveryMap.setView([delivery.latitude, delivery.longitude], 15);
                }
            }

            // Refresh map size
            setTimeout(() => {
                deliveryMap.invalidateSize();
            }, 100);
        })
        .catch(error => {
            console.error('Error loading delivery locations:', error);
            document.getElementById('pickupAddress').textContent = 'Error loading pickup address';
            document.getElementById('deliveryAddress').textContent = 'Error loading delivery address';
            document.getElementById('routeDistance').textContent = 'Error calculating distance';
        });
}

function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
}

function hideMap() {
    const mapContainer = document.getElementById('mapContainer');
    mapContainer.style.display = 'none';
    currentDeliveryId = null;
    clearMultiOrderView();
}

function normalizeDeliveriesResponse(response) {
    if (Array.isArray(response)) return response;
    if (response && Array.isArray(response.deliveries)) return response.deliveries;
    return [];
}

function clearMultiOrderView() {
    // Clear all markers and routes from multi-order view
    allMarkers.forEach(marker => {
        if (deliveryMap && marker) deliveryMap.removeLayer(marker);
    });
    allRoutes.forEach(route => {
        if (deliveryMap && route) deliveryMap.removeLayer(route);
    });
    allMarkers = [];
    allRoutes = [];
    isMultiOrderView = false;
}

async function showAllOrdersMap() {
    if (!deliveryMap) {
        initializeMap();
        if (!deliveryMap) return;
    }

    const mapContainer = document.getElementById('mapContainer');
    const mapTitle = document.getElementById('mapTitle');
    
    mapContainer.style.display = 'block';
    mapTitle.textContent = 'All Active Deliveries';
    
    // Clear existing markers and routes
    clearMultiOrderView();
    isMultiOrderView = true;

    try {
        // Get all deliveries visible to this rider, including available pickups and active routes
        const data = normalizeDeliveriesResponse(await API.rider.getDeliveries().catch(() => []));
        const activeOrders = data.filter(d => ['ready_for_pickup', 'in_transit'].includes(d.status));
        
        if (activeOrders.length === 0) {
            document.getElementById('pickupAddress').textContent = 'No active deliveries found';
            document.getElementById('deliveryAddress').textContent = 'No active deliveries found';
            document.getElementById('routeDistance').textContent = 'No active deliveries';
            return;
        }

        let bounds = [];
        let totalDistance = 0;
        let pickupAddresses = [];
        let deliveryAddresses = [];

        // Add markers for each order
        for (const order of activeOrders) {
            const pickupLat = order.pickup_latitude;
            const pickupLng = order.pickup_longitude;
            const deliveryLat = order.delivery_latitude;
            const deliveryLng = order.delivery_longitude;

            // Add pickup marker
            if (pickupLat && pickupLng) {
                const pickupMarker = L.marker([pickupLat, pickupLng], {
                    icon: L.divIcon({
                        className: 'custom-marker pickup-marker-icon',
                        html: '<div style="background:#007bff;color:white;border-radius:50%;width:25px;height:25px;display:flex;align-items:center;justify-content:center;font-size:12px;border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3)">&#128230;</div>',
                        iconSize: [25, 25],
                        iconAnchor: [12, 12]
                    })
                }).addTo(deliveryMap);
                
                pickupMarker.bindPopup(`
                    <div style="text-align:center;">
                        <strong>&#128230; Pickup</strong><br>
                        <small>Order #${(order.id || '').slice(0,8)}</small><br>
                        <small>${order.pickup_address || 'Address not available'}</small>
                    </div>
                `);
                
                allMarkers.push(pickupMarker);
                bounds.push([pickupLat, pickupLng]);
                pickupAddresses.push(order.pickup_address || 'Address not available');
            }

            // Add delivery marker
            if (deliveryLat && deliveryLng) {
                const deliveryMarker = L.marker([deliveryLat, deliveryLng], {
                    icon: L.divIcon({
                        className: 'custom-marker delivery-marker-icon',
                        html: '<div style="background:#dc3545;color:white;border-radius:50%;width:25px;height:25px;display:flex;align-items:center;justify-content:center;font-size:12px;border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3)">&#127919;</div>',
                        iconSize: [25, 25],
                        iconAnchor: [12, 12]
                    })
                }).addTo(deliveryMap);
                
                deliveryMarker.bindPopup(`
                    <div style="text-align:center;">
                        <strong>&#127919; Delivery</strong><br>
                        <small>Order #${(order.id || '').slice(0,8)}</small><br>
                        <small>${order.address || 'Address not available'}</small>
                    </div>
                `);
                
                allMarkers.push(deliveryMarker);
                bounds.push([deliveryLat, deliveryLng]);
                deliveryAddresses.push(order.address || 'Address not available');
            }

            // Draw route line if both coordinates exist
            if (pickupLat && pickupLng && deliveryLat && deliveryLng) {
                const routeLine = L.polyline([[pickupLat, pickupLng], [deliveryLat, deliveryLng]], {
                    color: '#28a745',
                    weight: 3,
                    opacity: 0.6,
                    dashArray: '5, 5'
                }).addTo(deliveryMap);
                
                allRoutes.push(routeLine);
                
                // Calculate distance
                const distance = calculateDistance(pickupLat, pickupLng, deliveryLat, deliveryLng);
                totalDistance += distance;
            }
        }

        // Update map display
        if (bounds.length > 0) {
            // Fit map to show all markers
            const group = new L.featureGroup(allMarkers);
            deliveryMap.fitBounds(group.getBounds().pad(0.15));
            
            // Update address displays
            document.getElementById('pickupAddress').textContent = 
                `${pickupAddresses.length} pickup locations:\n${pickupAddresses.slice(0, 3).join('\n')}${pickupAddresses.length > 3 ? '\n...' : ''}`;
            document.getElementById('deliveryAddress').textContent = 
                `${deliveryAddresses.length} delivery locations:\n${deliveryAddresses.slice(0, 3).join('\n')}${deliveryAddresses.length > 3 ? '\n...' : ''}`;
            document.getElementById('routeDistance').textContent = 
                `${activeOrders.length} active deliveries • Total distance: ${totalDistance.toFixed(2)} km`;
        } else {
            document.getElementById('pickupAddress').textContent = 'No coordinates available';
            document.getElementById('deliveryAddress').textContent = 'No coordinates available';
            document.getElementById('routeDistance').textContent = 'No coordinates available';
        }

        // Refresh map size
        setTimeout(() => {
            deliveryMap.invalidateSize();
        }, 100);

    } catch (error) {
        console.error('Error loading all deliveries:', error);
        document.getElementById('pickupAddress').textContent = 'Error loading deliveries';
        document.getElementById('deliveryAddress').textContent = 'Error loading deliveries';
        document.getElementById('routeDistance').textContent = 'Error loading deliveries';
    }
}
// -- Deliveries ------------------------------------------------
async function loadDeliveries(filter = 'all') {
    const tbody = document.getElementById('deliveriesTable');
    if (!tbody) return;

    const rawData  = await API.rider.getDeliveries().catch(() => []);
    const data     = normalizeDeliveriesResponse(rawData);
    const filtered = filter === 'all' ? data : data.filter(d => d.status === filter);

    if (!filtered.length) {
        tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">&#128666;</div>No deliveries found.</div></td></tr>`;
        return;
    }

    tbody.innerHTML = filtered.map(d => {
        const hasCoords = (d.pickup_latitude && d.pickup_longitude) || (d.delivery_latitude && d.delivery_longitude);
        const mapBtn    = hasCoords ? `<button class="btn btn-view" onclick="showDeliveryRoute('${d.id}')" style="margin-right:4px">&#128205; Map</button>` : '';
        const payment   = (d.payment_method || 'cod').toUpperCase();

        let actionBtn = '—';
        if (d.status === 'ready_for_pickup') {
            actionBtn = `
                <button class="btn btn-view" onclick="acceptDelivery('${d.id}')">Accept</button>
                <button class="btn btn-reject" onclick="openDeclineModal('${d.id}')" style="margin-left:4px">Decline</button>
            `;
        } else if (d.status === 'in_transit') {
            actionBtn = `
                <button class="btn btn-approve" onclick="markDelivered('${d.id}')">Mark Delivered</button>
                <button class="btn btn-reject" onclick="openDeclineModal('${d.id}', true)" style="margin-left:4px">Report</button>
            `;
        } else if (d.status === 'delivered' && d.proof_of_delivery_url) {
            actionBtn = `<button class="btn btn-view" onclick="viewProof('${d.proof_of_delivery_url}', '${d.proof_uploaded_at || ''}')">&#128247; Proof</button>`;
        }

        return `
            <tr>
                <td>#${(d.id || '').slice(0,8)}</td>
                <td>${d.customer_name || '—'}</td>
                <td>${d.address       || '—'}</td>
                <td><span class="badge" style="background:#e8f4fd;color:#1a6fa8">${payment}</span></td>
                <td><span class="badge badge-${d.status}">${d.status.replace(/_/g,' ')}</span></td>
                <td class="actions">${mapBtn}${actionBtn}</td>
            </tr>
        `;
    }).join('');
}

async function acceptDelivery(id) {
    const res = await API.rider.acceptDelivery(id).catch(() => ({ error: 'Network error.' }));
    if (res.success) {
        showToast('Delivery accepted!');
        loadDeliveries();
    } else {
        showToast(res.error || 'Failed.', true);
    }
}

async function markDelivered(id) {
    const modal = document.createElement('div');
    modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:9999';
    modal.innerHTML = `
        <div style="background:#fff;border-radius:16px;padding:24px;width:400px;max-width:90vw">
            <h3 style="margin:0 0 16px;font-size:18px;font-weight:700;color:#1a1a3e">Upload Proof of Delivery</h3>
            <p style="margin:0 0 16px;font-size:14px;color:#666">Upload a photo before marking as delivered.</p>
            <input type="file" id="proofFile" accept="image/jpeg,image/png,image/webp" style="width:100%;padding:10px;border:1px solid #e8e8f0;border-radius:8px;margin-bottom:12px">
            <div id="proofPreview" style="margin-bottom:12px;text-align:center"></div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
                <button onclick="this.closest('[style*=fixed]').remove()" style="padding:8px 16px;border:1px solid #e8e8f0;border-radius:8px;background:#fff;cursor:pointer;font-size:13px">Cancel</button>
                <button id="uploadProofBtn" style="padding:8px 16px;background:#FF2BAC;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:13px;font-weight:600">Upload & Mark Delivered</button>
            </div>
        </div>
    `;
    document.body.appendChild(modal);

    const fileInput = modal.querySelector('#proofFile');
    const preview   = modal.querySelector('#proofPreview');
    fileInput.addEventListener('change', e => {
        const file = e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = ev => { preview.innerHTML = `<img src="${ev.target.result}" style="max-width:100%;max-height:200px;border-radius:8px">`; };
        reader.readAsDataURL(file);
    });

    modal.querySelector('#uploadProofBtn').onclick = async () => {
        const file = fileInput.files[0];
        if (!file) { showToast('Please select an image file', true); return; }

        const btn = modal.querySelector('#uploadProofBtn');
        btn.disabled = true; btn.textContent = 'Uploading...';

        const formData = new FormData();
        formData.append('proof_image', file);

        try {
            const res = await fetch(`/rider/api/deliveries/${id}/proof`, {
                method: 'POST',
                headers: { 'X-CSRF-Token': getCSRFToken() },
                body: formData
            }).then(r => r.json());

            if (res.success) {
                showToast('Proof uploaded! Marking as delivered...');
                modal.remove();
                const statusRes = await API.rider.updateStatus(id, 'delivered');
                if (statusRes.success) { showToast('Delivery completed!'); loadDeliveries(); }
                else showToast(statusRes.error || 'Failed to update status', true);
            } else {
                showToast(res.error || 'Failed to upload proof', true);
                btn.disabled = false; btn.textContent = 'Upload & Mark Delivered';
            }
        } catch {
            showToast('Network error. Please try again.', true);
            btn.disabled = false; btn.textContent = 'Upload & Mark Delivered';
        }
    };
}

// -- Decline / Report modal ------------------------------------
let _declineOrderId = null;
let _declineIsReport = false;

async function openDeclineModal(orderId, isReport = false) {
    _declineOrderId = orderId;
    _declineIsReport = isReport;

    const modal = document.getElementById('declineModal');
    document.getElementById('declineModalTitle').textContent = isReport ? 'Report Issue' : 'Decline Order';
    document.getElementById('declineModalDesc').textContent  = isReport ? 'Select a reason for reporting:' : 'Please select a reason:';
    document.getElementById('declineNote').value = '';

    const reasons = await API.rider.getDeclineReasons().catch(() => ({ decline: [], report: [] }));
    const list    = isReport ? (reasons.report || []) : (reasons.decline || []);
    document.getElementById('declineReasons').innerHTML = list.map(r => `
        <label style="display:flex;align-items:center;gap:8px;font-size:13px;cursor:pointer">
            <input type="radio" name="declineReason" value="${r}"> ${r}
        </label>
    `).join('');

    modal.classList.add('open');
}

function closeDeclineModal() {
    document.getElementById('declineModal')?.classList.remove('open');
    _declineOrderId = null;
}

async function submitDecline() {
    const selected = document.querySelector('input[name="declineReason"]:checked');
    if (!selected) { showToast('Please select a reason', true); return; }
    const reason = selected.value;
    const note   = document.getElementById('declineNote').value.trim();

    const btn = document.getElementById('declineSubmitBtn');
    btn.disabled = true;

    const fn  = _declineIsReport ? API.rider.reportIssue : API.rider.declineDelivery;
    const res = await fn(_declineOrderId, reason, note).catch(() => ({ error: 'Network error.' }));

    btn.disabled = false;
    if (res.success) {
        showToast(_declineIsReport ? 'Issue reported.' : 'Order declined.');
        closeDeclineModal();
        loadDeliveries();
    } else {
        showToast(res.error || 'Failed.', true);
    }
}

// -- Proof viewer ----------------------------------------------
function viewProof(url, uploadedAt) {
    const modal = document.getElementById('proofViewModal');
    document.getElementById('proofViewImg').src  = url;
    document.getElementById('proofViewDate').textContent = uploadedAt ? 'Uploaded: ' + formatDate(uploadedAt) : '';
    modal.classList.add('open');
}

function getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
}

function setFilterTab(el, callback, value) {
    document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
    el.classList.add('active');
    callback(value);
}

// -- Availability ---------------------------------------------
async function loadAvailability() {
    const data = await API.rider.getAvailability().catch(() => ({}));
    _setAvailUI(data.is_available !== false);
}

async function toggleAvailability() {
    const dot = document.getElementById('availDot');
    const isNowAvailable = dot && dot.classList.contains('offline');
    const res = await API.rider.setAvailability(isNowAvailable).catch(() => ({}));
    if (res.success !== false) _setAvailUI(isNowAvailable);
}

function _setAvailUI(available) {
    const dot   = document.getElementById('availDot');
    const label = document.getElementById('availLabel');
    if (dot)   { dot.classList.toggle('offline', !available); dot.classList.toggle('online', available); }
    if (label) label.textContent = available ? 'Online' : 'Offline';
}

// -- Notifications --------------------------------------------
async function loadNotifications() {
    const data = await API.rider.getNotifications().catch(() => ({ notifications: [], unread_count: 0 }));
    const count = data.unread_count || 0;
    const countEl = document.getElementById('notifCount');
    const badge   = document.getElementById('sidebarBadge');
    if (countEl) { countEl.textContent = count; countEl.style.display = count ? 'inline' : 'none'; }
    if (badge)   { badge.textContent   = count; badge.style.display   = count ? 'inline' : 'none'; }

    const list = document.getElementById('notifList');
    if (!list) return;
    const notifs = data.notifications || [];
    if (!notifs.length) {
        list.innerHTML = '<div class="empty-state" style="padding:20px">No notifications</div>';
        return;
    }
    list.innerHTML = notifs.map(n => `
        <div class="notif-item${n.is_read ? '' : ' unread'}">
            <div class="notif-title">${n.title || ''}</div>
            <div class="notif-msg">${n.message || ''}</div>
            <div class="notif-time">${formatDate(n.created_at)}</div>
        </div>
    `).join('');
}

function toggleNotifPanel() {
    const panel = document.getElementById('notifPanel');
    if (!panel) return;
    panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
}

async function markAllNotifsRead() {
    await API.rider.markNotifsRead().catch(() => {});
    loadNotifications();
}

// -- Performance ----------------------------------------------
async function loadPerformance() {
    const data = await API.rider.getPerformance().catch(() => ({}));
    const set  = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    set('perfRating', data.avg_rating   != null ? data.avg_rating + ' ⭐' : '—');
    set('perfTotal',  data.total_deliveries || 0);
    set('perfAccept', data.acceptance_rate  != null ? data.acceptance_rate + '%' : '—%');
    set('perfLate',   data.late_percentage  != null ? data.late_percentage  + '%' : '—%');
}

// -- Rider Dashboard -------------------------------------------
let riderEarningsChart = null;

async function loadRiderDashboard() {
    const data = await API.rider.getDashboard().catch(() => ({}));

    const set = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    set('statToday',        data.completed_deliveries || 0);
    set('statCompleted',    data.completed_deliveries || 0);
    set('statActive',       data.active_deliveries    || 0);
    set('statAvailable',    data.available_orders     || 0);
    set('statEarningsToday', formatCurrency(data.today_earnings || 0));
    set('earningsBig',      formatCurrency(data.total_earnings  || 0));
    set('earningsToday',    formatCurrency(data.today_earnings  || 0));
    set('earningsWeek',     formatCurrency(data.week_earnings   || 0));
    set('earningsMonth',    formatCurrency(data.month_earnings  || 0));
    const rateLabel = document.getElementById('rateLabel');
    if (rateLabel) rateLabel.textContent = `₱${data.rate_per_delivery || 50} per delivery`;

    // Active orders quick list
    const activeList = document.getElementById('activeOrdersList');
    if (activeList) {
        const active = (data.recent_deliveries || []).filter(d => d.status === 'in_transit');
        if (!active.length) {
            activeList.innerHTML = '<div class="empty-state" style="padding:24px"><div class="empty-icon">🚚</div>No active orders</div>';
        } else {
            activeList.innerHTML = active.map(d => `
                <div class="active-order-row">
                    <div class="active-order-info">
                        <div class="active-order-id">#${(d.id||'').slice(0,8).toUpperCase()} &mdash; ${d.customer_name||'&mdash;'}</div>
                        <div class="active-order-addr">${d.address||'&mdash;'}</div>
                    </div>
                    <button class="btn btn-approve" onclick="markDelivered('${d.id}')">Deliver</button>
                </div>
            `).join('');
        }
    }

    const chart  = data.chart || [];
    const canvas = document.getElementById('riderEarningsChart');
    if (canvas) {
        if (riderEarningsChart) riderEarningsChart.destroy();
        riderEarningsChart = new Chart(canvas, {
            type: 'bar',
            data: {
                labels: chart.map(d => d.label),
                datasets: [{ label: 'Earnings (₱)', data: chart.map(d => d.value), backgroundColor: 'rgba(26,26,62,.15)', borderColor: '#1a1a3e', borderWidth: 2, borderRadius: 6 }]
            },
            options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '₱' + v } } } }
        });
    }

    const tbody = document.getElementById('riderRecentDeliveries');
    if (tbody) {
        const history = data.history || [];
        if (!history.length) {
            tbody.innerHTML = '<tr><td colspan="5"><div class="empty-state"><div class="empty-icon">&#128666;</div>No deliveries yet.</div></td></tr>';
        } else {
            tbody.innerHTML = history.map(h => `
                <tr>
                    <td>#${h.order_id}</td>
                    <td>${h.customer_name || '—'}</td>
                    <td style="color:#28a745;font-weight:600">${formatCurrency(h.amount)}</td>
                    <td>—</td>
                    <td><span class="badge badge-delivered">delivered</span></td>
                </tr>
            `).join('');
        }
    }
}

// -- Profile page ---------------------------------------------
const DAYS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

async function loadProfile() {
    const [profile, perf] = await Promise.all([
        API.rider.getProfile().catch(() => ({})),
        API.rider.getPerformance().catch(() => ({}))
    ]);

    const set = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };

    // Personal info
    const nameEl  = document.getElementById('pName');
    const phoneEl = document.getElementById('pPhone');
    if (nameEl  && profile.name)  nameEl.value  = profile.name;
    if (phoneEl && profile.phone) phoneEl.value = profile.phone;

    // Vehicle
    const v = profile.vehicle || {};
    const sel = (id, val) => { const el = document.getElementById(id); if (el && val) el.value = val; };
    sel('vType',  v.type);
    sel('vPlate', v.plate);
    sel('vModel', v.model);
    sel('vColor', v.color);

    // License
    const l = profile.license || {};
    sel('licenseNum',    l.number);
    sel('licenseExpiry', l.expiry);

    // Performance
    set('ppRating', perf.avg_rating    != null ? perf.avg_rating + ' ⭐' : '—');
    set('ppTotal',  perf.total_deliveries || 0);
    set('ppAccept', perf.acceptance_rate  != null ? perf.acceptance_rate + '%' : '—%');
    set('ppLate',   perf.late_percentage  != null ? perf.late_percentage  + '%' : '—%');

    const stars = document.getElementById('ratingStars');
    if (stars) {
        const r = perf.avg_rating;
        stars.textContent = r != null ? '⭐'.repeat(Math.round(r)) + ` (${r})` : '—';
    }

    // Schedule grid
    const grid = document.getElementById('scheduleGrid');
    if (grid) {
        const sched = profile.schedule || {};
        grid.innerHTML = DAYS.map(day => {
            const on = sched[day] !== false;
            return `
                <label class="schedule-day${on ? ' active' : ''}" id="sched-${day}" onclick="toggleDay('${day}')">
                    <input type="checkbox" id="day-${day}" ${on ? 'checked' : ''} style="display:none">
                    <span>${day}</span>
                </label>
            `;
        }).join('');
    }
}

function toggleDay(day) {
    const cb    = document.getElementById(`day-${day}`);
    const label = document.getElementById(`sched-${day}`);
    if (!cb) return;
    cb.checked = !cb.checked;
    label.classList.toggle('active', cb.checked);
}

async function saveProfile(e) {
    e.preventDefault();
    const res = await API.rider.saveProfile({
        name:  document.getElementById('pName')?.value.trim(),
        phone: document.getElementById('pPhone')?.value.trim(),
    }).catch(() => ({ error: 'Network error.' }));
    showToast(res.success ? 'Profile saved!' : (res.error || 'Failed.'), !res.success);
}

async function saveVehicle(e) {
    e.preventDefault();
    const res = await API.rider.saveProfile({
        vehicle: {
            type:  document.getElementById('vType')?.value,
            plate: document.getElementById('vPlate')?.value.trim(),
            model: document.getElementById('vModel')?.value.trim(),
            color: document.getElementById('vColor')?.value.trim(),
        }
    }).catch(() => ({ error: 'Network error.' }));
    showToast(res.success ? 'Vehicle saved!' : (res.error || 'Failed.'), !res.success);
}

async function saveLicense() {
    const res = await API.rider.saveProfile({
        license: {
            number: document.getElementById('licenseNum')?.value.trim(),
            expiry: document.getElementById('licenseExpiry')?.value,
        }
    }).catch(() => ({ error: 'Network error.' }));
    showToast(res.success ? 'License saved!' : (res.error || 'Failed.'), !res.success);
}

async function saveSchedule() {
    const sched = {};
    DAYS.forEach(day => {
        sched[day] = document.getElementById(`day-${day}`)?.checked ?? true;
    });
    const res = await API.rider.saveProfile({ schedule: sched }).catch(() => ({ error: 'Network error.' }));
    showToast(res.success ? 'Schedule saved!' : (res.error || 'Failed.'), !res.success);
}

function previewDoc(inputId, previewId) {
    const file = document.getElementById(inputId)?.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = ev => {
        const el = document.getElementById(previewId);
        if (el) el.innerHTML = `<img src="${ev.target.result}" style="max-width:100%;max-height:160px;border-radius:8px">`;
    };
    reader.readAsDataURL(file);
}

// -- Earnings page ---------------------------------------------
let earningsPageChart = null;
const DAILY_GOAL = 500;

async function loadEarnings() {
    const data = await API.rider.getEarnings().catch(() => ({}));
    const set  = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };

    set('totalEarnings',   formatCurrency(data.total  || 0));
    set('monthEarnings',   formatCurrency(data.month  || 0));
    set('weekEarnings',    formatCurrency(data.week   || 0));
    set('totalDeliveries', data.deliveries ?? 0);

    // COD collected — sum order_total for COD orders
    const history = data.history || [];
    const codTotal = history
        .filter(h => (h.payment_method || 'cod').toLowerCase() === 'cod')
        .reduce((sum, h) => sum + (h.order_total || 0), 0);
    set('codCollected', formatCurrency(codTotal));

    // Daily goal bar
    const todayEarned = data.today || 0;
    const pct = Math.min(100, Math.round((todayEarned / DAILY_GOAL) * 100));
    const goalFill  = document.getElementById('goalFill');
    const goalLabel = document.getElementById('goalLabel');
    const goalMsg   = document.getElementById('goalMsg');
    if (goalFill)  goalFill.style.width = pct + '%';
    if (goalLabel) goalLabel.textContent = `${formatCurrency(todayEarned)} / ${formatCurrency(DAILY_GOAL)}`;
    if (goalMsg)   goalMsg.textContent   = pct >= 100 ? '🎉 Goal reached!' : pct >= 50 ? 'More than halfway there!' : 'Keep going!';

    // Chart
    const chart  = data.chart || [];
    const canvas = document.getElementById('earningsChart');
    if (canvas) {
        if (earningsPageChart) earningsPageChart.destroy();
        earningsPageChart = new Chart(canvas, {
            type: 'bar',
            data: {
                labels: chart.map(d => d.label),
                datasets: [{ label: 'Earnings (₱)', data: chart.map(d => d.value), backgroundColor: 'rgba(26,26,62,.15)', borderColor: '#1a1a3e', borderWidth: 2, borderRadius: 6 }]
            },
            options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '₱' + v } } } }
        });
    }

    // History table — 5 columns: Date, Order ID, Order Total, Payment, Earned
    const tbody = document.getElementById('earningsHistory');
    if (tbody) {
        if (!history.length) {
            tbody.innerHTML = '<tr><td colspan="5"><div class="empty-state"><div class="empty-icon">💰</div>No earnings yet.</div></td></tr>';
        } else {
            tbody.innerHTML = history.map(h => {
                const payment = (h.payment_method || 'cod').toUpperCase();
                return `
                <tr>
                    <td>${formatDate(h.created_at)}</td>
                    <td>#${h.order_id}</td>
                    <td>${formatCurrency(h.order_total)}</td>
                    <td><span class="badge" style="background:#e8f4fd;color:#1a6fa8">${payment}</span></td>
                    <td style="color:#28a745;font-weight:600">${formatCurrency(h.amount)}</td>
                </tr>`;
            }).join('');
        }
    }
}
