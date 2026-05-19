from flask import Blueprint, request, jsonify
from services.shipping_calculator import ShippingFeeCalculator
from services.order_service import OrderService

shipping_api_bp = Blueprint('shipping_api', __name__)

@shipping_api_bp.route('/shipping/calculate', methods=['POST'])
def calculate_shipping():
    """Calculate shipping fee based on distance or coordinates"""
    try:
        data = request.get_json() or {}
        
        # Option 1: Distance provided directly
        distance_km = data.get('distance_km')
        if distance_km:
            fee = ShippingFeeCalculator.calculate(float(distance_km))
            breakdown = ShippingFeeCalculator.get_breakdown(float(distance_km))
            return jsonify({
                'success': True,
                'shipping_fee': fee,
                'breakdown': breakdown
            })
        
        # Option 2: Calculate from coordinates
        buyer_lat = data.get('buyer_lat')
        buyer_lng = data.get('buyer_lng')
        seller_lat = data.get('seller_lat')
        seller_lng = data.get('seller_lng')
        
        if all([buyer_lat, buyer_lng, seller_lat, seller_lng]):
            order_service = OrderService()
            distance = order_service.calculate_distance(
                seller_lat, seller_lng, buyer_lat, buyer_lng
            )
            fee = ShippingFeeCalculator.calculate(distance)
            breakdown = ShippingFeeCalculator.get_breakdown(distance)
            return jsonify({
                'success': True,
                'distance_km': distance,
                'shipping_fee': fee,
                'breakdown': breakdown
            })
        
        return jsonify({
            'success': False,
            'error': 'Please provide either distance_km or coordinates'
        }), 400
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@shipping_api_bp.route('/shipping/rates', methods=['GET'])
def get_shipping_rates():
    """Get shipping rate configuration"""
    return jsonify({
        'success': True,
        'rates': {
            'base_fee': ShippingFeeCalculator.BASE_FEE,
            'per_km_rate': ShippingFeeCalculator.PER_KM_RATE,
            'min_fee': ShippingFeeCalculator.MIN_FEE
        },
        'examples': [
            {'distance': 5, 'fee': ShippingFeeCalculator.calculate(5)},
            {'distance': 10, 'fee': ShippingFeeCalculator.calculate(10)},
            {'distance': 15, 'fee': ShippingFeeCalculator.calculate(15)},
            {'distance': 20, 'fee': ShippingFeeCalculator.calculate(20)},
        ]
    })
