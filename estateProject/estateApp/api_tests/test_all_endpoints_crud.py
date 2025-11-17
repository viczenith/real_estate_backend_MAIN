from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model

from estateApp.models import (
    CustomUser, Message, PlotSize, PlotNumber, Estate, PlotSizeUnits, EstatePlot,
    PlotAllocation, Notification, UserNotification, EstateFloorPlan, EstatePrototype,
    EstateAmenitie, EstateLayout, EstateMap, ProgressStatus, PropertyRequest
)

User = get_user_model()

# Base class for tests to create a user and log in
class BaseAPITest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="estate@gmail.com",
            full_name="Estate User",
            phone="1234567890",
            password="123"
        )
        # Log in the user; if you're using token auth, set the token in headers instead.
        self.client.login(email="estate@gmail.com", password="123")


# =============================
# CustomUser Endpoint Tests
# =============================
class CustomUserCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.user_list_url = reverse('customuser-list')
    
    def test_list_customusers(self):
        response = self.client.get(self.user_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_customuser(self):
        data = {
            "email": "newuser@example.com",
            "full_name": "New User",
            "phone": "0987654321",
            "password": "password123"
        }
        response = self.client.post(self.user_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_customuser(self):
        user_detail_url = reverse('customuser-detail', kwargs={'pk': self.user.id})
        update_data = {
            "full_name": "Updated Estate User",
            "phone": "1112223333",
            "email": self.user.email  # email is required and unique
        }
        response = self.client.put(user_detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_customuser(self):
        user_detail_url = reverse('customuser-detail', kwargs={'pk': self.user.id})
        patch_data = {"phone": "5555555555"}
        response = self.client.patch(user_detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_customuser(self):
        user_detail_url = reverse('customuser-detail', kwargs={'pk': self.user.id})
        response = self.client.delete(user_detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# Message Endpoint Tests
# =============================
class MessageCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.message_list_url = reverse('message-list')
        self.message = Message.objects.create(
            sender=self.user,
            recipient=self.user,
            message_type="enquiry",
            content="Test message"
        )
    
    def test_list_messages(self):
        response = self.client.get(self.message_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_message(self):
        data = {
            "sender": self.user.id,
            "recipient": self.user.id,
            "message_type": "complaint",
            "content": "Another test message"
        }
        response = self.client.post(self.message_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_message(self):
        detail_url = reverse('message-detail', kwargs={'pk': self.message.id})
        update_data = {
            "sender": self.user.id,
            "recipient": self.user.id,
            "message_type": "enquiry",
            "content": "Updated test message"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_message(self):
        detail_url = reverse('message-detail', kwargs={'pk': self.message.id})
        patch_data = {"content": "Partially updated message"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_message(self):
        detail_url = reverse('message-detail', kwargs={'pk': self.message.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# PlotSize Endpoint Tests
# =============================
class PlotSizeCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.plotsize_list_url = reverse('plotsize-list')
        self.plotsize = PlotSize.objects.create(size="Medium")
    
    def test_list_plotsizes(self):
        response = self.client.get(self.plotsize_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_plotsize(self):
        data = {"size": "Large"}
        response = self.client.post(self.plotsize_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_plotsize(self):
        detail_url = reverse('plotsize-detail', kwargs={'pk': self.plotsize.id})
        update_data = {"size": "Updated Medium"}
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_plotsize(self):
        detail_url = reverse('plotsize-detail', kwargs={'pk': self.plotsize.id})
        patch_data = {"size": "Partial Medium"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_plotsize(self):
        detail_url = reverse('plotsize-detail', kwargs={'pk': self.plotsize.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# PlotNumber Endpoint Tests
# =============================
class PlotNumberCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.plotnumber_list_url = reverse('plotnumber-list')
        self.plotnumber = PlotNumber.objects.create(number="PN-001")
    
    def test_list_plotnumbers(self):
        response = self.client.get(self.plotnumber_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_plotnumber(self):
        data = {"number": "PN-002"}
        response = self.client.post(self.plotnumber_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_plotnumber(self):
        detail_url = reverse('plotnumber-detail', kwargs={'pk': self.plotnumber.id})
        update_data = {"number": "PN-001-Updated"}
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_plotnumber(self):
        detail_url = reverse('plotnumber-detail', kwargs={'pk': self.plotnumber.id})
        patch_data = {"number": "PN-Partial"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_plotnumber(self):
        detail_url = reverse('plotnumber-detail', kwargs={'pk': self.plotnumber.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# Estate Endpoint Tests
# =============================
class EstateCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate_list_url = reverse('estate-list')
        self.estate = Estate.objects.create(
            name="Initial Estate",
            location="Initial Location",
            estate_size="1000 sqft",
            title_deed="FCDA CofO"
        )
    
    def test_list_estates(self):
        response = self.client.get(self.estate_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estate(self):
        data = {
            "name": "New Estate",
            "location": "New Location",
            "estate_size": "1500 sqft",
            "title_deed": "FCDA CofO"
        }
        response = self.client.post(self.estate_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estate(self):
        detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        update_data = {
            "name": "Updated Estate",
            "location": "Updated Location",
            "estate_size": "2000 sqft",
            "title_deed": "FCDA CofO"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estate(self):
        detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        patch_data = {"location": "Partially Updated Location"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estate(self):
        detail_url = reverse('estate-detail', kwargs={'pk': self.estate.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# PlotSizeUnits Endpoint Tests
# =============================
class PlotSizeUnitsCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Estate for Units",
            location="Location",
            estate_size="1200 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Small")
        self.estateplot = EstatePlot.objects.create(estate=self.estate)
        self.estateplot.plot_sizes.add(self.plotsize)
        self.plotsizeunit_list_url = reverse('plotsizeunit-list')
        self.plotsizeunit = PlotSizeUnits.objects.create(
            estate_plot=self.estateplot,
            plot_size=self.plotsize,
            total_units=10,
            available_units=10
        )
    
    def test_list_plotsizeunits(self):
        response = self.client.get(self.plotsizeunit_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_plotsizeunit(self):
        data = {
            "estate_plot": self.estateplot.id,
            "plot_size": self.plotsize.id,
            "total_units": 20,
            "available_units": 20
        }
        response = self.client.post(self.plotsizeunit_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_plotsizeunit(self):
        detail_url = reverse('plotsizeunit-detail', kwargs={'pk': self.plotsizeunit.id})
        update_data = {
            "estate_plot": self.estateplot.id,
            "plot_size": self.plotsize.id,
            "total_units": 15,
            "available_units": 15
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_plotsizeunit(self):
        detail_url = reverse('plotsizeunit-detail', kwargs={'pk': self.plotsizeunit.id})
        patch_data = {"total_units": 18}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_plotsizeunit(self):
        detail_url = reverse('plotsizeunit-detail', kwargs={'pk': self.plotsizeunit.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstatePlot Endpoint Tests
# =============================
class EstatePlotCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="EstatePlot Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Medium")
        self.plotnumber = PlotNumber.objects.create(number="P1")
        self.estateplot_list_url = reverse('estateplot-list')
        self.estateplot = EstatePlot.objects.create(estate=self.estate)
        self.estateplot.plot_sizes.add(self.plotsize)
        self.estateplot.plot_numbers.add(self.plotnumber)
    
    def test_list_estateplots(self):
        response = self.client.get(self.estateplot_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estateplot(self):
        data = {"estate": self.estate.id}
        response = self.client.post(self.estateplot_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estateplot(self):
        detail_url = reverse('estateplot-detail', kwargs={'pk': self.estateplot.id})
        update_data = {"estate": self.estate.id}
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estateplot(self):
        detail_url = reverse('estateplot-detail', kwargs={'pk': self.estateplot.id})
        patch_data = {}  # Nothing specific to update for now
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estateplot(self):
        detail_url = reverse('estateplot-detail', kwargs={'pk': self.estateplot.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# PlotAllocation Endpoint Tests
# =============================
class PlotAllocationCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Allocation Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Large")
        self.plotnumber = PlotNumber.objects.create(number="P2")
        self.estateplot = EstatePlot.objects.create(estate=self.estate)
        self.estateplot.plot_sizes.add(self.plotsize)
        self.estateplot.plot_numbers.add(self.plotnumber)
        self.plotsizeunit = PlotSizeUnits.objects.create(
            estate_plot=self.estateplot,
            plot_size=self.plotsize,
            total_units=10,
            available_units=10
        )
        self.plotallocation_list_url = reverse('plotallocation-list')
        self.plotallocation = PlotAllocation.objects.create(
            plot_size_unit=self.plotsizeunit,
            client=self.user,
            estate=self.estate,
            plot_size=self.plotsize,
            plot_number=self.plotnumber,
            payment_type="full"
        )
    
    def test_list_plotallocations(self):
        response = self.client.get(self.plotallocation_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_plotallocation(self):
        data = {
            "plot_size_unit": self.plotsizeunit.id,
            "client": self.user.id,
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "plot_number": self.plotnumber.id,
            "payment_type": "part"
        }
        response = self.client.post(self.plotallocation_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_plotallocation(self):
        detail_url = reverse('plotallocation-detail', kwargs={'pk': self.plotallocation.id})
        update_data = {
            "plot_size_unit": self.plotsizeunit.id,
            "client": self.user.id,
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "plot_number": self.plotnumber.id,
            "payment_type": "full"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_plotallocation(self):
        detail_url = reverse('plotallocation-detail', kwargs={'pk': self.plotallocation.id})
        patch_data = {"payment_type": "part"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_plotallocation(self):
        detail_url = reverse('plotallocation-detail', kwargs={'pk': self.plotallocation.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# Notification Endpoint Tests
# =============================
class NotificationCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.notification_list_url = reverse('notification-list')
        self.notification = Notification.objects.create(
            notification_type="ANNOUNCEMENT",
            title="Test Notification",
            message="Test message"
        )
    
    def test_list_notifications(self):
        response = self.client.get(self.notification_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_notification(self):
        data = {
            "notification_type": "CLIENT_ANNOUNCEMENT",
            "title": "New Notification",
            "message": "Notification message"
        }
        response = self.client.post(self.notification_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_notification(self):
        detail_url = reverse('notification-detail', kwargs={'pk': self.notification.id})
        update_data = {
            "notification_type": "MARKETER_ANNOUNCEMENT",
            "title": "Updated Notification",
            "message": "Updated message"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_notification(self):
        detail_url = reverse('notification-detail', kwargs={'pk': self.notification.id})
        patch_data = {"title": "Partially Updated"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_notification(self):
        detail_url = reverse('notification-detail', kwargs={'pk': self.notification.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# UserNotification Endpoint Tests
# =============================
class UserNotificationCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.notification = Notification.objects.create(
            notification_type="ANNOUNCEMENT",
            title="User Notif",
            message="Test user notification"
        )
        self.usernotification_list_url = reverse('usernotification-list')
        self.usernotification = UserNotification.objects.create(
            user=self.user,
            notification=self.notification
        )
    
    def test_list_usernotifications(self):
        response = self.client.get(self.usernotification_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_usernotification(self):
        data = {
            "user": self.user.id,
            "notification": self.notification.id
        }
        response = self.client.post(self.usernotification_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_usernotification(self):
        detail_url = reverse('usernotification-detail', kwargs={'pk': self.usernotification.id})
        update_data = {
            "user": self.user.id,
            "notification": self.notification.id
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_usernotification(self):
        detail_url = reverse('usernotification-detail', kwargs={'pk': self.usernotification.id})
        patch_data = {}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_usernotification(self):
        detail_url = reverse('usernotification-detail', kwargs={'pk': self.usernotification.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstateFloorPlan Endpoint Tests
# =============================
class EstateFloorPlanCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="FloorPlan Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Medium")
        self.floorplan_list_url = reverse('estatefloorplan-list')
        dummy_image = SimpleUploadedFile("test.jpg", b"file_content", content_type="image/jpeg")
        self.floorplan = EstateFloorPlan.objects.create(
            estate=self.estate,
            plot_size=self.plotsize,
            floor_plan_image=dummy_image,
            plan_title="Plan 1"
        )
    
    def test_list_estatefloorplans(self):
        response = self.client.get(self.floorplan_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estatefloorplan(self):
        dummy_image = SimpleUploadedFile("test2.jpg", b"file_content", content_type="image/jpeg")
        data = {
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "floor_plan_image": dummy_image,
            "plan_title": "Plan 2"
        }
        response = self.client.post(self.floorplan_list_url, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estatefloorplan(self):
        detail_url = reverse('estatefloorplan-detail', kwargs={'pk': self.floorplan.id})
        dummy_image = SimpleUploadedFile("updated.jpg", b"file_content", content_type="image/jpeg")
        update_data = {
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "floor_plan_image": dummy_image,
            "plan_title": "Updated Plan"
        }
        response = self.client.put(detail_url, update_data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estatefloorplan(self):
        detail_url = reverse('estatefloorplan-detail', kwargs={'pk': self.floorplan.id})
        patch_data = {"plan_title": "Partially Updated Plan"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estatefloorplan(self):
        detail_url = reverse('estatefloorplan-detail', kwargs={'pk': self.floorplan.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstatePrototype Endpoint Tests
# =============================
class EstatePrototypeCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Prototype Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Large")
        self.prototype_list_url = reverse('estateprototype-list')
        dummy_image = SimpleUploadedFile("proto.jpg", b"file_content", content_type="image/jpeg")
        self.prototype = EstatePrototype.objects.create(
            estate=self.estate,
            plot_size=self.plotsize,
            prototype_image=dummy_image,
            Title="Prototype 1"
        )
    
    def test_list_estateprototypes(self):
        response = self.client.get(self.prototype_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estateprototype(self):
        dummy_image = SimpleUploadedFile("proto2.jpg", b"file_content", content_type="image/jpeg")
        data = {
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "prototype_image": dummy_image,
            "Title": "Prototype 2"
        }
        response = self.client.post(self.prototype_list_url, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estateprototype(self):
        detail_url = reverse('estateprototype-detail', kwargs={'pk': self.prototype.id})
        dummy_image = SimpleUploadedFile("updatedproto.jpg", b"file_content", content_type="image/jpeg")
        update_data = {
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "prototype_image": dummy_image,
            "Title": "Updated Prototype"
        }
        response = self.client.put(detail_url, update_data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estateprototype(self):
        detail_url = reverse('estateprototype-detail', kwargs={'pk': self.prototype.id})
        patch_data = {"Title": "Partially Updated Prototype"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estateprototype(self):
        detail_url = reverse('estateprototype-detail', kwargs={'pk': self.prototype.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstateAmenitie Endpoint Tests
# =============================
class EstateAmenitieCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Amenitie Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.amenitie_list_url = reverse('estateamenitie-list')
        self.amenitie = EstateAmenitie.objects.create(
            estate=self.estate,
            amenities=["gated_security", "swimming_pool"]
        )
    
    def test_list_estateamenities(self):
        response = self.client.get(self.amenitie_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estateamenitie(self):
        data = {
            "estate": self.estate.id,
            "amenities": ["power_backup", "gym"]
        }
        response = self.client.post(self.amenitie_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estateamenitie(self):
        detail_url = reverse('estateamenitie-detail', kwargs={'pk': self.amenitie.id})
        update_data = {
            "estate": self.estate.id,
            "amenities": ["gated_security", "swimming_pool", "gym"]
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estateamenitie(self):
        detail_url = reverse('estateamenitie-detail', kwargs={'pk': self.amenitie.id})
        patch_data = {"amenities": ["gated_security"]}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estateamenitie(self):
        detail_url = reverse('estateamenitie-detail', kwargs={'pk': self.amenitie.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstateLayout Endpoint Tests
# =============================
class EstateLayoutCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Layout Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.layout_list_url = reverse('estatelayout-list')
        dummy_image = SimpleUploadedFile("layout.jpg", b"file_content", content_type="image/jpeg")
        self.layout = EstateLayout.objects.create(
            estate=self.estate,
            layout_image=dummy_image
        )
    
    def test_list_estatelayouts(self):
        response = self.client.get(self.layout_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estatelayout(self):
        dummy_image = SimpleUploadedFile("layout2.jpg", b"file_content", content_type="image/jpeg")
        data = {
            "estate": self.estate.id,
            "layout_image": dummy_image
        }
        response = self.client.post(self.layout_list_url, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estatelayout(self):
        detail_url = reverse('estatelayout-detail', kwargs={'pk': self.layout.id})
        dummy_image = SimpleUploadedFile("updated_layout.jpg", b"file_content", content_type="image/jpeg")
        update_data = {
            "estate": self.estate.id,
            "layout_image": dummy_image
        }
        response = self.client.put(detail_url, update_data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estatelayout(self):
        detail_url = reverse('estatelayout-detail', kwargs={'pk': self.layout.id})
        patch_data = {}  # No updatable fields aside from image
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estatelayout(self):
        detail_url = reverse('estatelayout-detail', kwargs={'pk': self.layout.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# EstateMap Endpoint Tests
# =============================
class EstateMapCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Map Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.map_list_url = reverse('estatemap-list')
        self.map = EstateMap.objects.create(
            estate=self.estate,
            latitude=12.345678,
            longitude=98.765432,
            google_map_link="http://example.com/map"
        )
    
    def test_list_estatemaps(self):
        response = self.client.get(self.map_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_estatemap(self):
        data = {
            "estate": self.estate.id,
            "latitude": 11.111111,
            "longitude": 99.999999,
            "google_map_link": "http://example.com/newmap"
        }
        response = self.client.post(self.map_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_estatemap(self):
        detail_url = reverse('estatemap-detail', kwargs={'pk': self.map.id})
        update_data = {
            "estate": self.estate.id,
            "latitude": 22.222222,
            "longitude": 88.888888,
            "google_map_link": "http://example.com/updatedmap"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_estatemap(self):
        detail_url = reverse('estatemap-detail', kwargs={'pk': self.map.id})
        patch_data = {"latitude": 33.333333}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_estatemap(self):
        detail_url = reverse('estatemap-detail', kwargs={'pk': self.map.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# ProgressStatus Endpoint Tests
# =============================
class ProgressStatusCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Progress Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.progressstatus_list_url = reverse('progressstatus-list')
        self.progressstatus = ProgressStatus.objects.create(
            estate=self.estate,
            progress_status="In Progress"
        )
    
    def test_list_progressstatuses(self):
        response = self.client.get(self.progressstatus_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_progressstatus(self):
        data = {
            "estate": self.estate.id,
            "progress_status": "Completed"
        }
        response = self.client.post(self.progressstatus_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_progressstatus(self):
        detail_url = reverse('progressstatus-detail', kwargs={'pk': self.progressstatus.id})
        update_data = {
            "estate": self.estate.id,
            "progress_status": "Updated Progress"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_progressstatus(self):
        detail_url = reverse('progressstatus-detail', kwargs={'pk': self.progressstatus.id})
        patch_data = {"progress_status": "Partially Updated"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_progressstatus(self):
        detail_url = reverse('progressstatus-detail', kwargs={'pk': self.progressstatus.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


# =============================
# PropertyRequest Endpoint Tests
# =============================
class PropertyRequestCRUDTest(BaseAPITest):
    def setUp(self):
        super().setUp()
        self.estate = Estate.objects.create(
            name="Request Estate",
            location="Location",
            estate_size="1500 sqft",
            title_deed="FCDA CofO"
        )
        self.plotsize = PlotSize.objects.create(size="Small")
        self.propertyrequest_list_url = reverse('propertyrequest-list')
        self.propertyrequest = PropertyRequest.objects.create(
            client=self.user,
            estate=self.estate,
            plot_size=self.plotsize,
            payment_type="full",
            status="Pending"
        )
    
    def test_list_propertyrequests(self):
        response = self.client.get(self.propertyrequest_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_propertyrequest(self):
        data = {
            "client": self.user.id,
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "payment_type": "part",
            "status": "Pending"
        }
        response = self.client.post(self.propertyrequest_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_update_propertyrequest(self):
        detail_url = reverse('propertyrequest-detail', kwargs={'pk': self.propertyrequest.id})
        update_data = {
            "client": self.user.id,
            "estate": self.estate.id,
            "plot_size": self.plotsize.id,
            "payment_type": "full",
            "status": "Approved"
        }
        response = self.client.put(detail_url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_partial_update_propertyrequest(self):
        detail_url = reverse('propertyrequest-detail', kwargs={'pk': self.propertyrequest.id})
        patch_data = {"status": "Cancelled"}
        response = self.client.patch(detail_url, patch_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_delete_propertyrequest(self):
        detail_url = reverse('propertyrequest-detail', kwargs={'pk': self.propertyrequest.id})
        response = self.client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
