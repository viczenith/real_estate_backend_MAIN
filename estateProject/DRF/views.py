# from rest_framework import viewsets, permissions, filters
# from rest_framework.permissions import IsAuthenticated, IsAdminUser
# from .serializers import *
# from estateApp.models import *


# class IsAdminOrReadOnly(permissions.BasePermission):
#     def has_permission(self, request, view):
#         if request.method in permissions.SAFE_METHODS:
#             return True
#         return bool(request.user and request.user.is_authenticated and request.user.role == "admin")

# class UserViewSet(viewsets.ReadOnlyModelViewSet):
#     queryset = CustomUser.objects.all()
#     serializer_class = CustomUserSerializer
#     permission_classes = [IsAuthenticated]
#     filter_backends = [filters.SearchFilter, filters.OrderingFilter]
#     search_fields = ["full_name", "email", "phone"]
#     ordering_fields = ["date_registered", "full_name"]

# class ClientViewSet(viewsets.ModelViewSet):
#     queryset = ClientUser.objects.select_related("assigned_marketer").all()
#     serializer_class = ClientUserSerializer
#     permission_classes = [IsAuthenticated]
#     http_method_names = ["get","post","put","patch","delete"]

# class MarketerViewSet(viewsets.ModelViewSet):
#     queryset = MarketerUser.objects.all()
#     serializer_class = MarketerUserSerializer
#     permission_classes = [IsAuthenticated]

# class EstateViewSet(viewsets.ModelViewSet):
#     queryset = Estate.objects.all()
#     serializer_class = EstateSerializer
#     permission_classes = [IsAdminOrReadOnly]
#     filter_backends = [filters.SearchFilter, filters.OrderingFilter]
#     search_fields = ["name", "location"]
#     ordering_fields = ["date_added", "name"]

# class PlotSizeViewSet(viewsets.ModelViewSet):
#     queryset = PlotSize.objects.all()
#     serializer_class = PlotSizeSerializer
#     permission_classes = [IsAdminOrReadOnly]

# class PlotNumberViewSet(viewsets.ModelViewSet):
#     queryset = PlotNumber.objects.all()
#     serializer_class = PlotNumberSerializer
#     permission_classes = [IsAdminOrReadOnly]

# class PlotSizeUnitsViewSet(viewsets.ModelViewSet):
#     queryset = PlotSizeUnits.objects.select_related("estate_plot", "plot_size").all()
#     serializer_class = PlotSizeUnitsSerializer
#     permission_classes = [IsAdminOrReadOnly]

# class PlotAllocationViewSet(viewsets.ModelViewSet):
#     queryset = PlotAllocation.objects.select_related("client","estate","plot_number","plot_size_unit").all()
#     serializer_class = PlotAllocationSerializer
#     permission_classes = [IsAuthenticated]
#     def perform_create(self, serializer):
#         # associate client with current user if creating own allocation (example)
#         serializer.save()

# class TransactionViewSet(viewsets.ModelViewSet):
#     queryset = Transaction.objects.select_related("client","allocation").all()
#     serializer_class = TransactionSerializer
#     permission_classes = [IsAuthenticated]

# class PaymentRecordViewSet(viewsets.ModelViewSet):
#     queryset = PaymentRecord.objects.all()
#     serializer_class = PaymentRecordSerializer
#     permission_classes = [IsAuthenticated]

# class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
#     queryset = Notification.objects.all()
#     serializer_class = NotificationSerializer
#     permission_classes = [IsAuthenticated]
