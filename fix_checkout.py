path = r'c:\Users\Admin\OneDrive\Documents\1-main\static\js\shop.js'
with open(path, 'r', encoding='utf-8') as f:
    d = f.read()

# FIX 2: loadAddressOptions - unwrap addresses + auto-select default
old2 = "    const data = await API.buyer.getAddresses().catch(() => []);\n    if (!data.length) {"
new2 = "    const raw = await API.buyer.getAddresses().catch(() => null);\n    const data = Array.isArray(raw) ? raw : (raw && raw.addresses ? raw.addresses : []);\n    if (!data.length) {"
print('fix2 found:', old2 in d)
d = d.replace(old2, new2)

# Auto-select default address after rendering the list
old2b = "    `).join('');\n}\n\nfunction selectAddress"
new2b = "    `).join('');\n\n    const defaultAddr = data.find(a => a.is_default) || data[0];\n    if (defaultAddr) document.getElementById('selectedAddressId').value = defaultAddr.id;\n}\n\nfunction selectAddress"
print('fix2b found:', old2b in d)
d = d.replace(old2b, new2b)

# FIX 3: placeOrder - read order_id from res.order.order_id
old3 = "    if (res.order_id) {\n        updateCartBadge();\n        window.location.href = `/buyer/order_summary?id=${res.order_id}`;"
new3 = "    const orderId = (res && res.order && res.order.order_id) ? res.order.order_id : res.order_id;\n    if (orderId) {\n        updateCartBadge();\n        window.location.href = `/buyer/order_summary?id=${orderId}`;"
print('fix3 found:', old3 in d)
d = d.replace(old3, new3)

with open(path, 'w', encoding='utf-8') as f:
    f.write(d)

print('All done.')
