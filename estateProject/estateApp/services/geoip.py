import ipaddress
from typing import Optional

import requests


def extract_client_ip(request) -> Optional[str]:
    """Best-effort extraction of client IP from a Django request.

    Order of precedence:
    - X-Forwarded-For (first IP)
    - CF-Connecting-IP (Cloudflare)
    - True-Client-IP (Akamai/others)
    - X-Real-IP (nginx)
    - REMOTE_ADDR (direct)

    Returns a string IP or None.
    """
    try:
        headers = request.META
        xff = headers.get('HTTP_X_FORWARDED_FOR')
        if xff:
            # may be a list of IPs: client, proxy1, proxy2...
            ip = xff.split(',')[0].strip()
            if ip:
                return ip

        cf_ip = headers.get('HTTP_CF_CONNECTING_IP')
        if cf_ip:
            return cf_ip.strip()

        true_client = headers.get('HTTP_TRUE_CLIENT_IP')
        if true_client:
            return true_client.strip()

        x_real_ip = headers.get('HTTP_X_REAL_IP')
        if x_real_ip:
            return x_real_ip.strip()

        return headers.get('REMOTE_ADDR')
    except Exception:
        return None


def is_private_ip(ip: str) -> bool:
    """Return True if the IP is loopback, link-local, or private (RFC1918)."""
    try:
        ip_obj = ipaddress.ip_address(ip)
        return ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_link_local
    except Exception:
        return True


def lookup_ip_location(ip: str, timeout_sec: float = 2.0) -> Optional[str]:
    """Lookup a human-readable location for an IP using ipapi.co.

    Returns a string like "City, Region, Country" or None if unavailable.
    Uses a short timeout and fails gracefully.
    """
    if not ip or is_private_ip(ip):
        # Localhost / private networks won't resolve to a public location
        if ip == '127.0.0.1' or ip == '::1':
            return 'Localhost'
        return 'Private Network'

    try:
        # ipapi.co supports unauthenticated lookups with rate limits.
        url = f"https://ipapi.co/{ip}/json/"
        resp = requests.get(url, timeout=timeout_sec)
        if resp.status_code != 200:
            return None
        data = resp.json() or {}
        if data.get('error'):
            return None
        city = (data.get('city') or '').strip()
        region = (data.get('region') or '').strip()
        country = (data.get('country_name') or '').strip()

        parts = [p for p in [city, region, country] if p]
        return ", ".join(parts) if parts else None
    except Exception:
        return None
