from rest_framework import serializers

class DashboardSummarySerializer(serializers.Serializer):
    total_transactions = serializers.IntegerField()
    total_estates_sold = serializers.IntegerField()
    number_clients = serializers.IntegerField()

class PerformanceBlockSerializer(serializers.Serializer):
    labels = serializers.ListField(child=serializers.CharField())
    tx = serializers.ListField(child=serializers.IntegerField())
    est = serializers.ListField(child=serializers.IntegerField())
    cli = serializers.ListField(child=serializers.IntegerField())

class DashboardFullSerializer(serializers.Serializer):
    summary = DashboardSummarySerializer()
    weekly = PerformanceBlockSerializer()
    monthly = PerformanceBlockSerializer()
    yearly = PerformanceBlockSerializer()
    alltime = PerformanceBlockSerializer()
