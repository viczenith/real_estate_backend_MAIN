from django.http import HttpResponse
from estateApp.models import Estate, PlotAllocation
import csv

def download_allocations(request):
    estate_id = request.GET.get('estate_id')
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return HttpResponse("Estate not found", status=404)

    # Gather all PlotNumber IDs from the estate's plots.
    # Here, we assume that the reverse relation from Estate to EstatePlot is named "estate_plots"
    # and that each EstatePlot has a related manager "plot_numbers" for its PlotNumber objects.
    plot_number_ids = []
    for estate_plot in estate.estate_plots.all():
        plot_numbers = estate_plot.plot_numbers.all()
        plot_number_ids.extend(plot_numbers.values_list('id', flat=True))
    
    # Now filter PlotAllocation objects whose plot_number id is in the collected list.
    allocations = PlotAllocation.objects.filter(plot_number__id__in=plot_number_ids)

    # Create CSV response.
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = f'attachment; filename="allocations_{estate_id}.csv"'
    
    writer = csv.writer(response)
    writer.writerow(['Client', 'Plot Size', 'Payment Type', 'Plot Number', 'Date Allocated'])
    for alloc in allocations:
        writer.writerow([
            alloc.client.full_name if hasattr(alloc.client, 'full_name') else '',
            alloc.plot_size_unit.plot_size.size if alloc.plot_size_unit and hasattr(alloc.plot_size_unit, 'plot_size') else '',
            alloc.get_payment_type_display() if hasattr(alloc, 'get_payment_type_display') else alloc.payment_type_display,
            alloc.plot_number.number if alloc.plot_number else '',
            alloc.date_allocated
        ])
    
    return response
