from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model

from estateApp.models import (
    Estate, Message, PlotSize, PlotNumber, PlotSizeUnits, EstatePlot,
    PlotAllocation, Notification, UserNotification, EstateFloorPlan, EstatePrototype,
    EstateAmenitie, EstateLayout, EstateMap, ProgressStatus, PropertyRequest
)

User = get_user_model()

class AllEndpointsTest(APITestCase):
    def setUp(self):
        # Create and login a test user
        self.user = User.objects.create_user(
            email="estate@gmail.com",
            full_name="Estate User",
            phone="1234567890",
            password="123"
        )
        # Using session authentication via client.login()
        self.client.login(email="estate@gmail.com", password="123")
        
        # Create a simple Estate for further objects
        self.estate = Estate.objects.create(
            name="Test Estate",
            location="Test Location",
            estate_size="1000 sqft",
            title_deed="FCDA CofO"
        )
        
        # Create a Message (using the test user as both sender and recipient)
        self.message = Message.objects.create(
            sender=self.user,
            recipient=self.user,
            message_type="enquiry",
            content="Test message"
        )
        
        # Create a PlotSize and PlotNumber
        self.plotsize = PlotSize.objects.create(size="Small")
        self.plotnumber = PlotNumber.objects.create(number="P1")
        
        # Create an EstatePlot and assign ManyToMany relations
        self.estateplot = EstatePlot.objects.create(estate=self.estate)
        self.estateplot.plot_sizes.add(self.plotsize)
        self.estateplot.plot_numbers.add(self.plotnumber)
        
        # Create PlotSizeUnits for the EstatePlot
        self.plotsizeunit = PlotSizeUnits.objects.create(
            estate_plot=self.estateplot,
            plot_size=self.plotsize,
            total_units=10,
            available_units=10
        )
        
        # Create a PlotAllocation
        self.plotallocation = PlotAllocation.objects.create(
            plot_size_unit=self.plotsizeunit,
            client=self.user,
            estate=self.estate,
            plot_size=self.plotsize,
            plot_number=self.plotnumber,
            payment_type="full"
        )
        
        # Create a Notification and corresponding UserNotification
        self.notification = Notification.objects.create(
            notification_type="ANNOUNCEMENT",
            title="Test Notification",
            message="Test notification message"
        )
        self.usernotification = UserNotification.objects.create(
            user=self.user,
            notification=self.notification
        )
        
        # Prepare a dummy image file for image fields
        dummy_image = SimpleUploadedFile("test.jpg", b"file_content", content_type="image/jpeg")
        
        # Create an EstateFloorPlan
        self.estatefloorplan = EstateFloorPlan.objects.create(
            estate=self.estate,
            plot_size=self.plotsize,
            floor_plan_image=dummy_image,
            plan_title="Floor Plan 1"
        )
        
        # Create an EstatePrototype
        self.estateprototype = EstatePrototype.objects.create(
            estate=self.estate,
            plot_size=self.plotsize,
            prototype_image=dummy_image,
            Title="Prototype 1"
        )
        
        # Create an EstateAmenitie with sample choices (amenities stored as a list)
        self.estateamenitie = EstateAmenitie.objects.create(
            estate=self.estate,
            amenities=["gated_security", "swimming_pool"]
        )
        
        # Create an EstateLayout
        self.estatelayout = EstateLayout.objects.create(
            estate=self.estate,
            layout_image=dummy_image
        )
        
        # Create an EstateMap
        self.estatemap = EstateMap.objects.create(
            estate=self.estate,
            latitude=12.345678,
            longitude=98.765432,
            google_map_link="http://example.com/map"
        )
        
        # Create a ProgressStatus
        self.progressstatus = ProgressStatus.objects.create(
            estate=self.estate,
            progress_status="In progress"
        )
        
        # Create a PropertyRequest
        self.propertyrequest = PropertyRequest.objects.create(
            client=self.user,
            estate=self.estate,
            plot_size=self.plotsize,
            payment_type="full",
            status="Pending"
        )

    def test_customuser_list(self):
        url = reverse('customuser-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_message_list(self):
        url = reverse('message-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_plotsize_list(self):
        url = reverse('plotsize-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_plotnumber_list(self):
        url = reverse('plotnumber-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estate_list(self):
        url = reverse('estate-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_plotsizeunit_list(self):
        url = reverse('plotsizeunit-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estateplot_list(self):
        url = reverse('estateplot-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_plotallocation_list(self):
        url = reverse('plotallocation-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_notification_list(self):
        url = reverse('notification-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_usernotification_list(self):
        url = reverse('usernotification-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estatefloorplan_list(self):
        url = reverse('estatefloorplan-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estateprototype_list(self):
        url = reverse('estateprototype-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estateamenitie_list(self):
        url = reverse('estateamenitie-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estatelayout_list(self):
        url = reverse('estatelayout-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_estatemap_list(self):
        url = reverse('estatemap-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_progressstatus_list(self):
        url = reverse('progressstatus-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)

    def test_propertyrequest_list(self):
        url = reverse('propertyrequest-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)
