# from rest_framework import serializers
# from estateApp.models import Estate

# class EstateSerializer(serializers.ModelSerializer):
#     class Meta:
#         model = Estate
#         fields = '__all__'


from rest_framework import serializers
from estateApp.models import Estate

class EstateSerializer(serializers.ModelSerializer):
    title_deed = serializers.CharField(source='get_title_deed_display')
    
    class Meta:
        model = Estate
        fields = ['id', 'name', 'location', 'estate_size', 'title_deed', 'date_added']



class EstateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estate
        fields = ['name', 'location', 'estate_size', 'title_deed']
