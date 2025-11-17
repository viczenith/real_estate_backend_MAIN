from rest_framework import serializers

from estateApp.models import UserDeviceToken


class DeviceTokenSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source="user.id", read_only=True)

    class Meta:
        model = UserDeviceToken
        fields = [
            "id",
            "user_id",
            "token",
            "platform",
            "app_version",
            "device_model",
            "is_active",
            "created_at",
            "last_seen",
        ]
        read_only_fields = ["id", "user_id", "is_active", "created_at", "last_seen"]

    def create(self, validated_data):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is None or not user.is_authenticated:
            raise serializers.ValidationError("Authentication required to register device tokens.")

        token = validated_data["token"]
        defaults = {
            "user": user,
            "platform": validated_data["platform"],
            "app_version": validated_data.get("app_version", ""),
            "device_model": validated_data.get("device_model", ""),
            "is_active": True,
        }

        instance, _ = UserDeviceToken.objects.update_or_create(token=token, defaults=defaults)
        instance.mark_seen(
            platform=defaults["platform"],
            app_version=defaults["app_version"],
            device_model=defaults["device_model"],
        )
        return instance
