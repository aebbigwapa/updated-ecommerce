"""
Shipping Fee Calculator Service
Calculates delivery fees based on distance
"""

class ShippingFeeCalculator:
    """Calculate shipping fees based on distance"""
    
    # Configuration
    BASE_FEE = 40  # Base delivery fee in pesos
    PER_KM_RATE = 10  # Rate per kilometer in pesos
    MIN_FEE = 50  # Minimum shipping fee
    MAX_FREE_DISTANCE = 0  # Distance in km for free shipping (0 = no free shipping)
    
    @staticmethod
    def calculate(distance_km):
        """
        Calculate shipping fee based on distance
        
        Args:
            distance_km (float): Distance in kilometers
            
        Returns:
            int: Shipping fee in pesos (rounded to nearest 10)
        """
        if distance_km <= 0:
            return ShippingFeeCalculator.MIN_FEE
        
        # Check for free shipping distance
        if ShippingFeeCalculator.MAX_FREE_DISTANCE > 0 and distance_km <= ShippingFeeCalculator.MAX_FREE_DISTANCE:
            return 0
        
        # Calculate: Base fee + (distance × rate per km)
        total = ShippingFeeCalculator.BASE_FEE + (distance_km * ShippingFeeCalculator.PER_KM_RATE)
        
        # Ensure minimum fee
        total = max(total, ShippingFeeCalculator.MIN_FEE)
        
        # Round to nearest 10 pesos
        return round(total / 10) * 10
    
    @staticmethod
    def get_breakdown(distance_km):
        """
        Get detailed breakdown of shipping fee
        
        Args:
            distance_km (float): Distance in kilometers
            
        Returns:
            dict: Breakdown with base_fee, distance_fee, total
        """
        if distance_km <= 0:
            return {
                'distance_km': 0,
                'base_fee': ShippingFeeCalculator.MIN_FEE,
                'distance_fee': 0,
                'total': ShippingFeeCalculator.MIN_FEE
            }
        
        base_fee = ShippingFeeCalculator.BASE_FEE
        distance_fee = distance_km * ShippingFeeCalculator.PER_KM_RATE
        total = base_fee + distance_fee
        total = max(total, ShippingFeeCalculator.MIN_FEE)
        total = round(total / 10) * 10
        
        return {
            'distance_km': round(distance_km, 2),
            'base_fee': base_fee,
            'distance_fee': round(distance_fee, 2),
            'total': total
        }
    
    @staticmethod
    def estimate_range(min_km, max_km):
        """
        Estimate shipping fee range
        
        Args:
            min_km (float): Minimum distance
            max_km (float): Maximum distance
            
        Returns:
            dict: Min and max shipping fees
        """
        return {
            'min_distance': min_km,
            'max_distance': max_km,
            'min_fee': ShippingFeeCalculator.calculate(min_km),
            'max_fee': ShippingFeeCalculator.calculate(max_km)
        }


# Example usage and testing
if __name__ == '__main__':
    print("Shipping Fee Calculator")
    print("=" * 50)
    print(f"Base Fee: ₱{ShippingFeeCalculator.BASE_FEE}")
    print(f"Per KM Rate: ₱{ShippingFeeCalculator.PER_KM_RATE}")
    print("=" * 50)
    
    # Test cases
    test_distances = [0, 1, 5, 10, 15, 20, 25, 30]
    
    for distance in test_distances:
        fee = ShippingFeeCalculator.calculate(distance)
        breakdown = ShippingFeeCalculator.get_breakdown(distance)
        print(f"\n{distance} km:")
        print(f"  Base Fee: ₱{breakdown['base_fee']}")
        print(f"  Distance Fee: ₱{breakdown['distance_fee']:.2f}")
        print(f"  Total: ₱{breakdown['total']}")
