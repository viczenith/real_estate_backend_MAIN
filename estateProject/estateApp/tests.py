from django.test import TestCase
from rest_framework.test import APITestCase
from django.urls import reverse
from rest_framework import status
from estateApp.models import Estate
from estateApp.serializers.estate_serializers import EstateSerializer
from django.contrib.auth import get_user_model

User = get_user_model()

class EstateAPITest(APITestCase):
    def setUp(self):
        # Create a test user and log in using the token
        self.user = User.objects.create_user(
            email='estate@gmail.com',
            full_name='Estate User',
            phone='1234567890',
            password='123'
        )
        # If using token authentication, you may need to fetch the token and set it in the client header.
        self.client.login(email='estate@gmail.com', password='123')
        
        # Create a sample Estate
        self.estate = Estate.objects.create(
            name="Test Estate",
            location="Test Location",
            estate_size="1000 sqft",
            title_deed="FCDA CofO"
        )
        self.url = reverse('estate-list')  # router basename 'estate' is used in your urls

    def test_get_estates(self):
        # Make a GET request to fetch estates
        response = self.client.get(self.url)
        estates = Estate.objects.all()
        serializer = EstateSerializer(estates, many=True)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, serializer.data)
