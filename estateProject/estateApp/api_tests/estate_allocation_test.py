import requests

def test_estate_full_allocation_details(estate_id, token, base_url):
    """
    Test the API endpoint /api/estate-full-allocation-details/<estateId>/
    
    :param estate_id: The ID of the estate to fetch details for (e.g., 1).
    :param token: The Bearer token for authentication.
    :param base_url: The base URL of the API (e.g., 'http://localhost:8000').
    """
    # Construct the full URL
    url = f"{base_url}/api/estate-full-allocation-details/{estate_id}/"
    
    # Set up headers with Bearer token
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Send GET request to the API
        response = requests.get(url, headers=headers)
        
        # Check if the request was successful
        if response.status_code == 200:
            # Parse and print the JSON response
            data = response.json()
            print("API Response:")
            print(data)
        else:
            # Handle unsuccessful requests
            print(f"Error: Received status code {response.status_code}")
            print(response.text)
    
    except requests.exceptions.RequestException as e:
        # Handle network or request errors
        print(f"Request failed: {e}")

# Example usage
if __name__ == "__main__":
    # Replace these with your actual values
    estate_id = 1  # Example estate ID
    token = 'your_token_here'  # Replace with your actual Bearer token
    base_url = 'http://localhost:8000'  # Replace with your API base URL
    
    # Call the function to test the API
    test_estate_full_allocation_details(estate_id, token, base_url)