from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from estateApp.models import (
    CustomUser, Message, PlotSize, PlotNumber, Estate, PlotSizeUnits, EstatePlot,
    PlotAllocation, Notification, UserNotification, EstateFloorPlan, EstatePrototype,
    EstateAmenitie, EstateLayout, EstateMap, ProgressStatus, PropertyRequest
)

from estateApp.serializers.user_serializers import CustomUserSerializer
from estateApp.serializers.message_serializer import MessageSerializer
from estateApp.serializers.estate_serializers import EstateSerializer
from estateApp.serializers.plot_and_allocation_serializers import (
    PlotSizeUnitsSerializer, EstatePlotSerializer, PlotAllocationSerializer
)
from estateApp.serializers.notification_serializers import (
    NotificationSerializer, UserNotificationSerializer
)
from estateApp.serializers.estate_assets_serializers import (
    EstateFloorPlanSerializer, EstatePrototypeSerializer, EstateAmenitieSerializer,
    EstateLayoutSerializer, EstateMapSerializer, ProgressStatusSerializer
)
from estateApp.serializers.requests_serializers import (
    PropertyRequestSerializer
)
from estateApp.serializers.simple_serializers import PlotSizeSerializer, PlotNumberSerializer
from rest_framework.decorators import action
from rest_framework.response import Response




class CustomUserViewSet(viewsets.ModelViewSet):
    queryset = CustomUser.objects.all()
    serializer_class = CustomUserSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['role']

    # Add a custom action for the current user
    @action(detail=False, methods=['get'], url_path='me')
    def get_current_user(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)


class MessageViewSet(viewsets.ModelViewSet):
    queryset = Message.objects.all()
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]


class PlotSizeViewSet(viewsets.ModelViewSet):
    queryset = PlotSize.objects.all().order_by('id')
    serializer_class = PlotSizeSerializer
    permission_classes = [IsAuthenticated]


class PlotNumberViewSet(viewsets.ModelViewSet):
    queryset = PlotNumber.objects.all().order_by('id')
    serializer_class = PlotNumberSerializer
    permission_classes = [IsAuthenticated]


class EstateViewSet(viewsets.ModelViewSet):
    queryset = Estate.objects.all()
    serializer_class = EstateSerializer
    permission_classes = [IsAuthenticated]


class PlotSizeUnitsViewSet(viewsets.ModelViewSet):
    queryset = PlotSizeUnits.objects.all()
    serializer_class = PlotSizeUnitsSerializer
    permission_classes = [IsAuthenticated]


class EstatePlotViewSet(viewsets.ModelViewSet):
    queryset = EstatePlot.objects.all()
    serializer_class = EstatePlotSerializer
    permission_classes = [IsAuthenticated]


class PlotAllocationViewSet(viewsets.ModelViewSet):
    queryset = PlotAllocation.objects.all()
    serializer_class = PlotAllocationSerializer
    permission_classes = [IsAuthenticated]


class NotificationViewSet(viewsets.ModelViewSet):
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]


class UserNotificationViewSet(viewsets.ModelViewSet):
    queryset = UserNotification.objects.all()
    serializer_class = UserNotificationSerializer
    permission_classes = [IsAuthenticated]


class EstateFloorPlanViewSet(viewsets.ModelViewSet):
    queryset = EstateFloorPlan.objects.all()
    serializer_class = EstateFloorPlanSerializer
    permission_classes = [IsAuthenticated]


class EstatePrototypeViewSet(viewsets.ModelViewSet):
    queryset = EstatePrototype.objects.all()
    serializer_class = EstatePrototypeSerializer
    permission_classes = [IsAuthenticated]


class EstateAmenitieViewSet(viewsets.ModelViewSet):
    queryset = EstateAmenitie.objects.all()
    serializer_class = EstateAmenitieSerializer
    permission_classes = [IsAuthenticated]


class EstateLayoutViewSet(viewsets.ModelViewSet):
    queryset = EstateLayout.objects.all()
    serializer_class = EstateLayoutSerializer
    permission_classes = [IsAuthenticated]


class EstateMapViewSet(viewsets.ModelViewSet):
    queryset = EstateMap.objects.all()
    serializer_class = EstateMapSerializer
    permission_classes = [IsAuthenticated]


class ProgressStatusViewSet(viewsets.ModelViewSet):
    queryset = ProgressStatus.objects.all()
    serializer_class = ProgressStatusSerializer
    permission_classes = [IsAuthenticated]


class PropertyRequestViewSet(viewsets.ModelViewSet):
    queryset = PropertyRequest.objects.all()
    serializer_class = PropertyRequestSerializer
    permission_classes = [IsAuthenticated]




