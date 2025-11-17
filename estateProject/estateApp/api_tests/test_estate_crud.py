from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.contrib.auth import get_user_model

from estateApp.models import Estate
from estateApp.serializers.estate_serializers import EstateSerializer

User = get_user_model()

class EstateCRUDTest(APITestCase):
    def setUp(self):
        # Create and authenticate a test user
        self.user = User.objects.create_user(
            email="estate@gmail.com",
            full_name="Estate User",
            phone="1234567890",
            password="123"
        )
        self.client.login(email="estate@gmail.com", password="123")
        
        # Set URL for listing/creating estates
        self.estate_list_url = reverse('estate-list')
        
        # Create an initial Estate instance to test update/delete operations
        self.estate = Estate.objects.create(
            name="Initial Estate",
            location="Initial Location",
            estate_size="1000 sqft",
            title_deed="FCDA CofO"
        )

    def test_create_estate(self):
        """Test creating a new Estate (POST)"""
        data = {
            "name": "New Estate",
            "location": "New Location",
            "estate_size": "1500 sqft",
            "title_deed": "FCDA CofO"
        }
        response = self.client.post(self.estate_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], data['name'])
        self.assertEqual(response.data['location'], data['location'])

    def test_update_estate(self):
        """Test updating an existing Estate using PUT"""
        update_data = {
            "name": "Updated Estate",
            "location": "Updated Location",
            "estate_size": "2000 sqft",
            "title_deed": "FCDA CofO"
        }
        # Get detail URL for the existing estate
        estate_detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        response = self.client.put(estate_detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], update_data['name'])
        self.assertEqual(response.data['location'], update_data['location'])

    def test_partial_update_estate(self):
        """Test partially updating an Estate using PATCH"""
        partial_data = {
            "location": "Partially Updated Location"
        }
        estate_detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        response = self.client.patch(estate_detail_url, partial_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['location'], partial_data['location'])

    def test_delete_estate(self):
        """Test deleting an Estate"""
        estate_detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        response = self.client.delete(estate_detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        # Verify deletion by attempting to retrieve the deleted estate
        response = self.client.get(estate_detail_url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_create_estate_invalid_data(self):
        """Edge Case: Test creating an Estate with missing required fields"""
        # Omit required field "name"
        data = {
            "location": "No Name Location",
            "estate_size": "1500 sqft",
            "title_deed": "FCDA CofO"
        }
        response = self.client.post(self.estate_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("name", response.data)
