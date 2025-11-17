from django.http import HttpResponse
from reportlab.pdfgen import canvas
from estateApp.models import Estate

def download_estate_pdf(request, estate_id):
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return HttpResponse("Estate not found", status=404)

    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="estate_{estate_id}.pdf"'

    p = canvas.Canvas(response)
    p.drawString(100, 800, f"Estate Details: {estate.name}")
    p.drawString(100, 780, f"Location: {estate.location}")
    p.drawString(100, 760, f"Size: {estate.estate_size}")
    p.showPage()
    p.save()
    return response
