from __future__ import annotations

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable


def build_carriers() -> list[dict[str, object]]:
    return [
        {"CarrierCode": "CAR001", "SCACCode": "ATLF", "CarrierName": "Atlas Freight", "CarrierMode": "Truckload", "CarrierTier": "National", "HomeCity": "Phoenix", "HomeStateProvince": "AZ", "ActiveFlag": 1},
        {"CarrierCode": "CAR002", "SCACCode": "CANY", "CarrierName": "Canyon Logistics", "CarrierMode": "LTL", "CarrierTier": "Regional", "HomeCity": "Denver", "HomeStateProvince": "CO", "ActiveFlag": 1},
        {"CarrierCode": "CAR003", "SCACCode": "DSRT", "CarrierName": "Desert Transport", "CarrierMode": "Truckload", "CarrierTier": "Regional", "HomeCity": "Las Vegas", "HomeStateProvince": "NV", "ActiveFlag": 1},
        {"CarrierCode": "CAR004", "SCACCode": "NRTH", "CarrierName": "Northline Carriers", "CarrierMode": "Intermodal", "CarrierTier": "National", "HomeCity": "Chicago", "HomeStateProvince": "IL", "ActiveFlag": 1},
        {"CarrierCode": "CAR005", "SCACCode": "BMFR", "CarrierName": "Blue Mesa Freight", "CarrierMode": "Truckload", "CarrierTier": "Regional", "HomeCity": "Albuquerque", "HomeStateProvince": "NM", "ActiveFlag": 1},
        {"CarrierCode": "CAR006", "SCACCode": "SUMD", "CarrierName": "Summit Delivery", "CarrierMode": "Parcel", "CarrierTier": "Last Mile", "HomeCity": "Salt Lake City", "HomeStateProvince": "UT", "ActiveFlag": 1},
        {"CarrierCode": "CAR007", "SCACCode": "WFLN", "CarrierName": "Western Freight Lines", "CarrierMode": "Truckload", "CarrierTier": "National", "HomeCity": "Los Angeles", "HomeStateProvince": "CA", "ActiveFlag": 1},
        {"CarrierCode": "CAR008", "SCACCode": "COPR", "CarrierName": "Copper State Logistics", "CarrierMode": "LTL", "CarrierTier": "Regional", "HomeCity": "Dallas", "HomeStateProvince": "TX", "ActiveFlag": 1},
        {"CarrierCode": "CAR009", "SCACCode": "PION", "CarrierName": "Pioneer Trucking", "CarrierMode": "Truckload", "CarrierTier": "Regional", "HomeCity": "Kansas City", "HomeStateProvince": "MO", "ActiveFlag": 1},
        {"CarrierCode": "CAR010", "SCACCode": "RPMC", "CarrierName": "Rapid Mile Carriers", "CarrierMode": "Parcel", "CarrierTier": "Last Mile", "HomeCity": "Atlanta", "HomeStateProvince": "GA", "ActiveFlag": 1},
        {"CarrierCode": "CAR011", "SCACCode": "SKLN", "CarrierName": "Skyline Freight", "CarrierMode": "Intermodal", "CarrierTier": "National", "HomeCity": "Seattle", "HomeStateProvince": "WA", "ActiveFlag": 1},
        {"CarrierCode": "CAR012", "SCACCode": "SNCT", "CarrierName": "Sun Coast Transport", "CarrierMode": "Truckload", "CarrierTier": "Regional", "HomeCity": "Miami", "HomeStateProvince": "FL", "ActiveFlag": 1},
    ]


def build_locations() -> list[dict[str, object]]:
    return [
        {"LocationCode": "PHX_DC", "LocationName": "Phoenix Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "1200 South 7th Avenue", "City": "Phoenix", "StateProvince": "AZ", "CountryCode": "US", "PostalCode": "85007", "Region": "Southwest", "Latitude": 33.440100, "Longitude": -112.082500, "ActiveFlag": 1},
        {"LocationCode": "TUS_HUB", "LocationName": "Tucson Hub", "LocationType": "Cross Dock", "AddressLine1": "415 West Toole Avenue", "City": "Tucson", "StateProvince": "AZ", "CountryCode": "US", "PostalCode": "85701", "Region": "Southwest", "Latitude": 32.222600, "Longitude": -110.974700, "ActiveFlag": 1},
        {"LocationCode": "LAS_HUB", "LocationName": "Las Vegas Hub", "LocationType": "Hub", "AddressLine1": "845 East Sahara Avenue", "City": "Las Vegas", "StateProvince": "NV", "CountryCode": "US", "PostalCode": "89104", "Region": "West", "Latitude": 36.154400, "Longitude": -115.143500, "ActiveFlag": 1},
        {"LocationCode": "LAX_DC", "LocationName": "Los Angeles Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "2400 Alameda Street", "City": "Los Angeles", "StateProvince": "CA", "CountryCode": "US", "PostalCode": "90058", "Region": "West", "Latitude": 34.014200, "Longitude": -118.230100, "ActiveFlag": 1},
        {"LocationCode": "SAN_DEP", "LocationName": "San Diego Depot", "LocationType": "Depot", "AddressLine1": "775 Harbor Drive", "City": "San Diego", "StateProvince": "CA", "CountryCode": "US", "PostalCode": "92101", "Region": "West", "Latitude": 32.706600, "Longitude": -117.160600, "ActiveFlag": 1},
        {"LocationCode": "SLC_HUB", "LocationName": "Salt Lake City Hub", "LocationType": "Hub", "AddressLine1": "550 West 200 South", "City": "Salt Lake City", "StateProvince": "UT", "CountryCode": "US", "PostalCode": "84101", "Region": "Mountain", "Latitude": 40.761900, "Longitude": -111.908400, "ActiveFlag": 1},
        {"LocationCode": "DEN_DC", "LocationName": "Denver Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "18600 East 48th Avenue", "City": "Denver", "StateProvince": "CO", "CountryCode": "US", "PostalCode": "80249", "Region": "Mountain", "Latitude": 39.780000, "Longitude": -104.773800, "ActiveFlag": 1},
        {"LocationCode": "ABQ_HUB", "LocationName": "Albuquerque Hub", "LocationType": "Hub", "AddressLine1": "700 1st Street NW", "City": "Albuquerque", "StateProvince": "NM", "CountryCode": "US", "PostalCode": "87102", "Region": "Southwest", "Latitude": 35.091700, "Longitude": -106.649400, "ActiveFlag": 1},
        {"LocationCode": "DAL_DC", "LocationName": "Dallas Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "2600 Commerce Street", "City": "Dallas", "StateProvince": "TX", "CountryCode": "US", "PostalCode": "75226", "Region": "South Central", "Latitude": 32.784700, "Longitude": -96.775600, "ActiveFlag": 1},
        {"LocationCode": "HOU_HUB", "LocationName": "Houston Hub", "LocationType": "Hub", "AddressLine1": "9201 Airport Boulevard", "City": "Houston", "StateProvince": "TX", "CountryCode": "US", "PostalCode": "77061", "Region": "South Central", "Latitude": 29.649700, "Longitude": -95.271400, "ActiveFlag": 1},
        {"LocationCode": "KC_DEP", "LocationName": "Kansas City Depot", "LocationType": "Depot", "AddressLine1": "420 Southwest Boulevard", "City": "Kansas City", "StateProvince": "MO", "CountryCode": "US", "PostalCode": "64108", "Region": "Midwest", "Latitude": 39.087500, "Longitude": -94.596400, "ActiveFlag": 1},
        {"LocationCode": "CHI_DC", "LocationName": "Chicago Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "1400 South Lumber Street", "City": "Chicago", "StateProvince": "IL", "CountryCode": "US", "PostalCode": "60607", "Region": "Midwest", "Latitude": 41.862500, "Longitude": -87.646500, "ActiveFlag": 1},
        {"LocationCode": "ATL_HUB", "LocationName": "Atlanta Hub", "LocationType": "Hub", "AddressLine1": "1700 Central Avenue", "City": "Atlanta", "StateProvince": "GA", "CountryCode": "US", "PostalCode": "30337", "Region": "Southeast", "Latitude": 33.640700, "Longitude": -84.427700, "ActiveFlag": 1},
        {"LocationCode": "MIA_DC", "LocationName": "Miami Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "3200 Northwest 67th Avenue", "City": "Miami", "StateProvince": "FL", "CountryCode": "US", "PostalCode": "33122", "Region": "Southeast", "Latitude": 25.804800, "Longitude": -80.302900, "ActiveFlag": 1},
        {"LocationCode": "ORL_DEP", "LocationName": "Orlando Delivery Depot", "LocationType": "Depot", "AddressLine1": "1020 Jetport Drive", "City": "Orlando", "StateProvince": "FL", "CountryCode": "US", "PostalCode": "32809", "Region": "Southeast", "Latitude": 28.449900, "Longitude": -81.344200, "ActiveFlag": 1},
        {"LocationCode": "SEA_DC", "LocationName": "Seattle Distribution Center", "LocationType": "Distribution Center", "AddressLine1": "1801 13th Avenue South", "City": "Seattle", "StateProvince": "WA", "CountryCode": "US", "PostalCode": "98144", "Region": "Pacific Northwest", "Latitude": 47.587600, "Longitude": -122.314900, "ActiveFlag": 1},
        {"LocationCode": "PDX_DEP", "LocationName": "Portland Delivery Depot", "LocationType": "Depot", "AddressLine1": "605 Northwest 13th Avenue", "City": "Portland", "StateProvince": "OR", "CountryCode": "US", "PostalCode": "97209", "Region": "Pacific Northwest", "Latitude": 45.526200, "Longitude": -122.684500, "ActiveFlag": 1},
        {"LocationCode": "OMA_HUB", "LocationName": "Omaha Hub", "LocationType": "Hub", "AddressLine1": "4501 Abbott Drive", "City": "Omaha", "StateProvince": "NE", "CountryCode": "US", "PostalCode": "68110", "Region": "Midwest", "Latitude": 41.303200, "Longitude": -95.894100, "ActiveFlag": 1},
    ]


def build_routes(rng: random.Random) -> list[dict[str, object]]:
    route_definitions = [
        ("RTE001", "PHX_DC", "LAX_DC", 372, "Regional"),
        ("RTE002", "PHX_DC", "LAS_HUB", 302, "Regional"),
        ("RTE003", "PHX_DC", "DAL_DC", 1065, "Long Haul"),
        ("RTE004", "TUS_HUB", "PHX_DC", 118, "Regional"),
        ("RTE005", "LAS_HUB", "DEN_DC", 748, "Long Haul"),
        ("RTE006", "LAX_DC", "SAN_DEP", 124, "Regional"),
        ("RTE007", "LAX_DC", "SLC_HUB", 690, "Long Haul"),
        ("RTE008", "SLC_HUB", "DEN_DC", 518, "Long Haul"),
        ("RTE009", "DEN_DC", "KC_DEP", 604, "Long Haul"),
        ("RTE010", "ABQ_HUB", "DAL_DC", 645, "Long Haul"),
        ("RTE011", "DAL_DC", "HOU_HUB", 241, "Regional"),
        ("RTE012", "DAL_DC", "CHI_DC", 968, "Long Haul"),
        ("RTE013", "KC_DEP", "CHI_DC", 510, "Long Haul"),
        ("RTE014", "CHI_DC", "DEN_DC", 1003, "Long Haul"),
        ("RTE015", "ATL_HUB", "MIA_DC", 664, "Long Haul"),
        ("RTE016", "ATL_HUB", "ORL_DEP", 439, "Regional"),
        ("RTE017", "DEN_DC", "SEA_DC", 1331, "Long Haul"),
        ("RTE018", "SEA_DC", "PDX_DEP", 174, "Regional"),
        ("RTE019", "HOU_HUB", "ATL_HUB", 793, "Long Haul"),
        ("RTE020", "CHI_DC", "ATL_HUB", 716, "Long Haul"),
        ("RTE021", "DAL_DC", "DEN_DC", 781, "Long Haul"),
        ("RTE022", "PHX_DC", "ABQ_HUB", 418, "Regional"),
        ("RTE023", "OMA_HUB", "CHI_DC", 469, "Regional"),
        ("RTE024", "DEN_DC", "OMA_HUB", 540, "Long Haul"),
    ]

    routes: list[dict[str, object]] = []
    for route_code, origin_code, destination_code, miles, route_type in route_definitions:
        average_speed = rng.uniform(45.0, 57.0)
        routes.append(
            {
                "RouteCode": route_code,
                "OriginLocationCode": origin_code,
                "DestinationLocationCode": destination_code,
                "RouteType": route_type,
                "StandardDistanceMiles": float(miles),
                "StandardTransitHours": round(miles / average_speed, 2),
                "ActiveFlag": 1,
                "EffectiveStartDate": "2024-01-01",
            }
        )
    return routes


def build_exception_codes() -> list[dict[str, object]]:
    return [
        {"ExceptionCode": "WX", "ExceptionDescription": "Weather Delay", "ExceptionCategory": "Weather", "SeverityCode": "High", "TypicalDelayMinutes": 720, "ResponsibleParty": "Carrier", "Weight": 12, "MinDelayMinutes": 240, "MaxDelayMinutes": 1680, "StatusCode": "WEATHER_HOLD", "StatusDescription": "Shipment delayed because of weather conditions."},
        {"ExceptionCode": "DAMG", "ExceptionDescription": "Damaged Shipment", "ExceptionCategory": "Damage", "SeverityCode": "High", "TypicalDelayMinutes": 1080, "ResponsibleParty": "Carrier", "Weight": 7, "MinDelayMinutes": 360, "MaxDelayMinutes": 2880, "StatusCode": "DAMAGE_REPORTED", "StatusDescription": "Shipment flagged for damage inspection."},
        {"ExceptionCode": "MSCN", "ExceptionDescription": "Missed Scan", "ExceptionCategory": "Process", "SeverityCode": "Medium", "TypicalDelayMinutes": 180, "ResponsibleParty": "Operations", "Weight": 9, "MinDelayMinutes": 30, "MaxDelayMinutes": 540, "StatusCode": "MISSED_SCAN_ALERT", "StatusDescription": "Expected scan was not captured on time."},
        {"ExceptionCode": "ADDR", "ExceptionDescription": "Address Issue", "ExceptionCategory": "Address", "SeverityCode": "Medium", "TypicalDelayMinutes": 540, "ResponsibleParty": "Customer", "Weight": 8, "MinDelayMinutes": 120, "MaxDelayMinutes": 1440, "StatusCode": "ADDRESS_REVIEW", "StatusDescription": "Delivery address requires correction or validation."},
        {"ExceptionCode": "MECH", "ExceptionDescription": "Equipment Failure", "ExceptionCategory": "Mechanical", "SeverityCode": "High", "TypicalDelayMinutes": 660, "ResponsibleParty": "Carrier", "Weight": 4, "MinDelayMinutes": 180, "MaxDelayMinutes": 1320, "StatusCode": "EQUIPMENT_BREAKDOWN", "StatusDescription": "Equipment failure caused an operational delay."},
        {"ExceptionCode": "CAP", "ExceptionDescription": "Capacity Constraint", "ExceptionCategory": "Capacity", "SeverityCode": "Medium", "TypicalDelayMinutes": 300, "ResponsibleParty": "Carrier", "Weight": 5, "MinDelayMinutes": 60, "MaxDelayMinutes": 960, "StatusCode": "CAPACITY_DELAY", "StatusDescription": "Shipment delayed due to available trailer or dock capacity."},
    ]


def choose_weighted(items: list[dict[str, object]], rng: random.Random) -> dict[str, object]:
    return rng.choices(items, weights=[int(item["Weight"]) for item in items], k=1)[0]


def add_scan_event(
    events: list[dict[str, object]],
    shipment_number: str,
    sequence_number: int,
    status_code: str,
    status_description: str,
    event_datetime: datetime,
    location_code: str | None,
    scan_type: str,
    event_source: str,
    exception_code: str | None = None,
    notes: str | None = None,
) -> int:
    events.append(
        {
            "ShipmentNumber": shipment_number,
            "EventSequenceNumber": sequence_number,
            "StatusCode": status_code,
            "StatusDescription": status_description,
            "EventDateTime": event_datetime.strftime("%Y-%m-%d %H:%M:%S"),
            "LocationCode": location_code or "",
            "ScanType": scan_type,
            "EventSource": event_source,
            "ExceptionCode": exception_code or "",
            "Notes": notes or "",
        }
    )
    return sequence_number + 1


def generate_source_data(
    carriers: list[dict[str, object]],
    locations: list[dict[str, object]],
    routes: list[dict[str, object]],
    exception_codes: list[dict[str, object]],
    shipment_count: int,
    rng: random.Random,
) -> tuple[list[dict[str, object]], list[dict[str, object]], list[dict[str, object]]]:
    analysis_end = datetime(2025, 10, 1, 12, 0, 0)
    analysis_start = datetime(2025, 1, 1, 6, 0, 0)
    span_minutes = int((analysis_end - analysis_start).total_seconds() // 60)

    shipments: list[dict[str, object]] = []
    scan_events: list[dict[str, object]] = []
    delivery_exceptions: list[dict[str, object]] = []

    for shipment_index in range(1, shipment_count + 1):
        route = rng.choice(routes)
        carrier = rng.choice(carriers)
        service_level = rng.choices(["Standard", "Priority", "Expedited"], weights=[65, 25, 10], k=1)[0]
        service_multiplier = {"Standard": 1.00, "Priority": 0.93, "Expedited": 0.87}[service_level]
        created_at = analysis_start + timedelta(minutes=rng.randint(0, span_minutes))
        planned_pickup = created_at + timedelta(hours=rng.randint(4, 18))
        planned_delivery = planned_pickup + timedelta(hours=float(route["StandardTransitHours"]) * service_multiplier + rng.uniform(-0.75, 1.50))
        actual_pickup = planned_pickup + timedelta(hours=rng.uniform(-1.50, 3.50))

        issue_profile: dict[str, object] | None = None
        if rng.random() < 0.38:
            issue_profile = choose_weighted(exception_codes, rng)

        if issue_profile is not None:
            delay_minutes = rng.randint(int(issue_profile["MinDelayMinutes"]), int(issue_profile["MaxDelayMinutes"]))
        elif rng.random() < 0.24:
            delay_minutes = rng.randint(30, 480)
        else:
            delay_minutes = rng.randint(-150, 90)

        due_by_now = planned_delivery <= analysis_end - timedelta(hours=6)
        shipment_still_open = not due_by_now and rng.random() < 0.55
        exception_left_open = issue_profile is not None and rng.random() < 0.12

        if shipment_still_open or exception_left_open:
            actual_delivery = None
            current_status = "Exception" if issue_profile is not None else rng.choices(["In Transit", "Out For Delivery"], weights=[70, 30], k=1)[0]
        else:
            actual_delivery = planned_delivery + timedelta(minutes=delay_minutes)
            current_status = "Delivered"

        planned_miles = round(float(route["StandardDistanceMiles"]) * rng.uniform(0.98, 1.03), 2)
        actual_miles = round(planned_miles * rng.uniform(0.45, 0.92), 2) if actual_delivery is None else round(planned_miles * rng.uniform(0.97, 1.14), 2)
        piece_count = rng.randint(1, 18)
        weight_lbs = round(rng.uniform(300.00, 42000.00), 2)
        shipment_revenue = round(planned_miles * rng.uniform(1.90, 4.60), 2)
        shipment_cost = round(shipment_revenue * rng.uniform(0.60, 0.88), 2)
        source_modified_at = (actual_delivery or max(planned_delivery, analysis_end - timedelta(hours=rng.randint(1, 36)))) + timedelta(hours=rng.randint(1, 8))

        shipment_number = f"SHP{shipment_index:07d}"
        shipments.append(
            {
                "ShipmentNumber": shipment_number,
                "CarrierCode": carrier["CarrierCode"],
                "RouteCode": route["RouteCode"],
                "OriginLocationCode": route["OriginLocationCode"],
                "DestinationLocationCode": route["DestinationLocationCode"],
                "CustomerReferenceNumber": f"ORD{shipment_index:08d}",
                "ServiceLevel": service_level,
                "CurrentStatus": current_status,
                "ShipmentCreateDateTime": created_at.strftime("%Y-%m-%d %H:%M:%S"),
                "PlannedPickupDateTime": planned_pickup.strftime("%Y-%m-%d %H:%M:%S"),
                "ActualPickupDateTime": actual_pickup.strftime("%Y-%m-%d %H:%M:%S"),
                "PlannedDeliveryDateTime": planned_delivery.strftime("%Y-%m-%d %H:%M:%S"),
                "ActualDeliveryDateTime": actual_delivery.strftime("%Y-%m-%d %H:%M:%S") if actual_delivery else "",
                "WeightLbs": weight_lbs,
                "PieceCount": piece_count,
                "ShipmentRevenue": shipment_revenue,
                "ShipmentCost": shipment_cost,
                "PlannedDistanceMiles": planned_miles,
                "ActualDistanceMiles": actual_miles,
                "SourceModifiedAt": source_modified_at.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

        sequence_number = 1
        sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "CREATED", "Shipment created in transportation management system.", created_at, route["OriginLocationCode"], "System", "TMS")
        sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "PICKUP_SCHEDULED", "Pickup appointment scheduled.", created_at + timedelta(hours=1), route["OriginLocationCode"], "System", "TMS")
        sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "PICKED_UP", "Shipment picked up from origin facility.", actual_pickup, route["OriginLocationCode"], "Scan", "Handheld")
        departed_origin = actual_pickup + timedelta(hours=rng.uniform(0.75, 3.00))
        sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "DEPARTED_ORIGIN", "Shipment departed origin facility.", departed_origin, route["OriginLocationCode"], "Scan", "Handheld")

        destination_hub_time = planned_delivery - timedelta(hours=rng.uniform(4.00, 9.00))
        if not (issue_profile is not None and issue_profile["ExceptionCode"] == "MSCN"):
            sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "AT_DESTINATION_HUB", "Shipment arrived at destination hub.", destination_hub_time, route["DestinationLocationCode"], "Scan", "EDI")

        if issue_profile is not None:
            issue_time = min(planned_delivery - timedelta(hours=rng.uniform(3.00, 16.00)), analysis_end - timedelta(hours=1))
            if actual_delivery is not None:
                resolution_datetime = min(actual_delivery - timedelta(hours=rng.uniform(0.50, 6.00)), actual_delivery)
            elif rng.random() < 0.35:
                resolution_datetime = issue_time + timedelta(hours=rng.uniform(6.00, 20.00))
            else:
                resolution_datetime = None

            delivery_exceptions.append(
                {
                    "ShipmentNumber": shipment_number,
                    "ExceptionCode": issue_profile["ExceptionCode"],
                    "ExceptionDescription": issue_profile["ExceptionDescription"],
                    "ExceptionCategory": issue_profile["ExceptionCategory"],
                    "SeverityCode": issue_profile["SeverityCode"],
                    "ExceptionStatus": "Closed" if resolution_datetime else "Open",
                    "ExceptionDateTime": issue_time.strftime("%Y-%m-%d %H:%M:%S"),
                    "ResolvedDateTime": resolution_datetime.strftime("%Y-%m-%d %H:%M:%S") if resolution_datetime else "",
                    "DelayMinutesImpact": max(delay_minutes, int(issue_profile["MinDelayMinutes"])),
                    "ResponsibleParty": issue_profile["ResponsibleParty"],
                    "Notes": issue_profile["StatusDescription"],
                }
            )

            exception_location = route["DestinationLocationCode"] if issue_profile["ExceptionCode"] in {"ADDR", "MSCN"} else route["OriginLocationCode"]
            sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, str(issue_profile["StatusCode"]), str(issue_profile["StatusDescription"]), issue_time, exception_location, "Alert", "CarrierEDI", str(issue_profile["ExceptionCode"]), str(issue_profile["StatusDescription"]))

            if resolution_datetime is not None:
                sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "RESOLVED", "Shipment exception resolved.", resolution_datetime, route["DestinationLocationCode"], "System", "TMS", str(issue_profile["ExceptionCode"]), "Exception closed and shipment released.")

        if actual_delivery is not None:
            out_for_delivery = actual_delivery - timedelta(hours=rng.uniform(1.50, 5.50))
            sequence_number = add_scan_event(scan_events, shipment_number, sequence_number, "OUT_FOR_DELIVERY", "Shipment is out for delivery.", out_for_delivery, route["DestinationLocationCode"], "Scan", "Handheld")
            add_scan_event(scan_events, shipment_number, sequence_number, "DELIVERED", "Shipment delivered to customer.", actual_delivery, route["DestinationLocationCode"], "Delivery", "Handheld")
        elif current_status == "Out For Delivery":
            out_for_delivery = max(planned_delivery - timedelta(hours=2), analysis_end - timedelta(hours=3))
            add_scan_event(scan_events, shipment_number, sequence_number, "OUT_FOR_DELIVERY", "Shipment is out for delivery.", out_for_delivery, route["DestinationLocationCode"], "Scan", "Handheld")
        else:
            last_event_time = max(destination_hub_time, analysis_end - timedelta(hours=rng.randint(2, 18)))
            add_scan_event(scan_events, shipment_number, sequence_number, "IN_TRANSIT" if current_status == "In Transit" else "EXCEPTION_OPEN", "Shipment remains in transit." if current_status == "In Transit" else "Shipment is pending exception resolution.", last_event_time, route["DestinationLocationCode"] if current_status == "Exception" else "", "System", "TMS", str(issue_profile["ExceptionCode"]) if issue_profile is not None else "", "Shipment not yet delivered." if current_status == "In Transit" else "Customer-impacting exception remains open.")

    return shipments, scan_events, delivery_exceptions


def build_warehouse_shipments(source_shipments: list[dict[str, object]]) -> list[dict[str, object]]:
    warehouse_shipments: list[dict[str, object]] = []
    analysis_time = datetime(2025, 10, 1, 12, 0, 0)
    for shipment in source_shipments:
        planned_delivery = datetime.strptime(str(shipment["PlannedDeliveryDateTime"]), "%Y-%m-%d %H:%M:%S")
        actual_delivery_text = str(shipment["ActualDeliveryDateTime"])
        actual_delivery = datetime.strptime(actual_delivery_text, "%Y-%m-%d %H:%M:%S") if actual_delivery_text else None

        if actual_delivery is not None:
            shipment_status = "Delivered"
        elif str(shipment["CurrentStatus"]) == "Exception" or planned_delivery < analysis_time:
            shipment_status = "Delayed"
        else:
            shipment_status = "In Transit"

        warehouse_shipments.append(
            {
                "ShipmentNumber": shipment["ShipmentNumber"],
                "CarrierCode": shipment["CarrierCode"],
                "RouteCode": shipment["RouteCode"],
                "OriginLocationCode": shipment["OriginLocationCode"],
                "DestinationLocationCode": shipment["DestinationLocationCode"],
                "ShipmentStatus": shipment_status,
                "ShipmentCreateDate": shipment["ShipmentCreateDateTime"],
                "PlannedPickupDate": shipment["PlannedPickupDateTime"],
                "ActualPickupDate": shipment["ActualPickupDateTime"],
                "PlannedDeliveryDate": shipment["PlannedDeliveryDateTime"],
                "ActualDeliveryDate": shipment["ActualDeliveryDateTime"],
                "WeightLbs": shipment["WeightLbs"],
                "ShipmentRevenue": shipment["ShipmentRevenue"],
                "ShipmentCost": shipment["ShipmentCost"],
                "PlannedDistanceMiles": shipment["PlannedDistanceMiles"],
                "ActualDistanceMiles": shipment["ActualDistanceMiles"],
                "ServiceLevel": shipment["ServiceLevel"],
                "SourceModifiedAt": shipment["SourceModifiedAt"],
            }
        )
    return warehouse_shipments


def build_warehouse_delivery_exceptions(source_delivery_exceptions: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "ShipmentNumber": row["ShipmentNumber"],
            "ExceptionCode": row["ExceptionCode"],
            "ExceptionDescription": row["ExceptionDescription"],
            "ExceptionCategory": row["ExceptionCategory"],
            "ExceptionDateTime": row["ExceptionDateTime"],
            "DelayMinutesImpact": row["DelayMinutesImpact"],
            "ResolvedDateTime": row["ResolvedDateTime"],
            "SeverityCode": row["SeverityCode"],
        }
        for row in source_delivery_exceptions
    ]


def build_warehouse_routes(routes: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "RouteCode": route["RouteCode"],
            "OriginLocationCode": route["OriginLocationCode"],
            "DestinationLocationCode": route["DestinationLocationCode"],
            "RouteType": route["RouteType"],
            "PlannedDistanceMiles": route["StandardDistanceMiles"],
            "PlannedTransitHours": route["StandardTransitHours"],
        }
        for route in routes
    ]


def build_warehouse_carriers(carriers: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "CarrierCode": carrier["CarrierCode"],
            "CarrierName": carrier["CarrierName"],
            "CarrierMode": carrier["CarrierMode"],
            "CarrierTier": carrier["CarrierTier"],
            "ActiveFlag": carrier["ActiveFlag"],
        }
        for carrier in carriers
    ]


def build_warehouse_locations(locations: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "LocationCode": location["LocationCode"],
            "LocationName": location["LocationName"],
            "City": location["City"],
            "StateProvince": location["StateProvince"],
            "CountryCode": location["CountryCode"],
            "PostalCode": location["PostalCode"],
            "Region": location["Region"],
            "Latitude": location["Latitude"],
            "Longitude": location["Longitude"],
        }
        for location in locations
    ]


def build_route_distance_reference(routes: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for route in routes:
        miles = float(route["StandardDistanceMiles"])
        if miles < 300:
            fuel_zone = "Short Haul"
        elif miles < 800:
            fuel_zone = "Mid Haul"
        else:
            fuel_zone = "Long Haul"

        rows.append(
            {
                "RouteCode": route["RouteCode"],
                "OriginLocationCode": route["OriginLocationCode"],
                "DestinationLocationCode": route["DestinationLocationCode"],
                "ReferenceDistanceMiles": route["StandardDistanceMiles"],
                "ReferenceTransitHours": route["StandardTransitHours"],
                "RouteType": route["RouteType"],
                "FuelZone": fuel_zone,
            }
        )
    return rows


def build_exception_code_lookup(exception_codes: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "ExceptionCode": row["ExceptionCode"],
            "ExceptionDescription": row["ExceptionDescription"],
            "ExceptionCategory": row["ExceptionCategory"],
            "SeverityCode": row["SeverityCode"],
            "TypicalDelayMinutes": row["TypicalDelayMinutes"],
            "ResponsibleParty": row["ResponsibleParty"],
            "ActiveFlag": 1,
        }
        for row in exception_codes
    ]


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def sql_literal(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "NULL" if value == "" else "N'" + value.replace("'", "''") + "'"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return format(value, ".6f").rstrip("0").rstrip(".")
    return "N'" + str(value).replace("'", "''") + "'"


def chunked(rows: list[dict[str, object]], batch_size: int) -> Iterable[list[dict[str, object]]]:
    for index in range(0, len(rows), batch_size):
        yield rows[index:index + batch_size]


def write_values_insert(handle, table_name: str, columns: list[str], rows: list[dict[str, object]], batch_size: int) -> None:
    for batch in chunked(rows, batch_size):
        handle.write(f"INSERT INTO {table_name}\n(\n")
        handle.write(",\n".join(f"    {column}" for column in columns))
        handle.write("\n)\nVALUES\n")
        handle.write(",\n".join(f"    ({', '.join(sql_literal(row[column]) for column in columns)})" for row in batch))
        handle.write(";\nGO\n\n")


def write_join_insert(
    handle,
    table_name: str,
    target_columns: list[str],
    source_columns: list[str],
    rows: list[dict[str, object]],
    batch_size: int,
    select_expressions: list[str],
    join_sql: str,
) -> None:
    for batch in chunked(rows, batch_size):
        handle.write(f"INSERT INTO {table_name}\n(\n")
        handle.write(",\n".join(f"    {column}" for column in target_columns))
        handle.write("\n)\nSELECT\n")
        handle.write(",\n".join(f"    {expression}" for expression in select_expressions))
        handle.write("\nFROM\n(\n    VALUES\n")
        handle.write(",\n".join(f"        ({', '.join(sql_literal(row[column]) for column in source_columns)})" for row in batch))
        handle.write("\n) AS v\n(\n")
        handle.write(",\n".join(f"    {column}" for column in source_columns))
        handle.write("\n)\n")
        handle.write(join_sql)
        handle.write(";\nGO\n\n")


def write_sql_seed(
    path: Path,
    carriers: list[dict[str, object]],
    locations: list[dict[str, object]],
    routes: list[dict[str, object]],
    shipments: list[dict[str, object]],
    scan_events: list[dict[str, object]],
    delivery_exceptions: list[dict[str, object]],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(":setvar DatabaseName TransportationDW\n\n")
        handle.write("USE [$(DatabaseName)];\nGO\n\n")
        handle.write("SET NOCOUNT ON;\nGO\n\n")
        handle.write("IF OBJECT_ID(N'src.Shipment', N'U') IS NULL\nBEGIN\n    THROW 50000, 'Run sql/source/01_create_source_schema.sql before seeding source data.', 1;\nEND;\nGO\n\n")
        handle.write("DELETE FROM src.Delivery_Exception;\nDELETE FROM src.Shipment_Status_History;\nDELETE FROM src.Shipment;\nDELETE FROM src.Route;\nDELETE FROM src.Carrier;\nDELETE FROM src.Location;\nGO\n\n")
        handle.write("DBCC CHECKIDENT ('src.Location', RESEED, 0) WITH NO_INFOMSGS;\nDBCC CHECKIDENT ('src.Carrier', RESEED, 0) WITH NO_INFOMSGS;\nDBCC CHECKIDENT ('src.Route', RESEED, 0) WITH NO_INFOMSGS;\nDBCC CHECKIDENT ('src.Shipment', RESEED, 0) WITH NO_INFOMSGS;\nDBCC CHECKIDENT ('src.Shipment_Status_History', RESEED, 0) WITH NO_INFOMSGS;\nDBCC CHECKIDENT ('src.Delivery_Exception', RESEED, 0) WITH NO_INFOMSGS;\nGO\n\n")

        write_values_insert(handle, "src.Location", ["LocationCode", "LocationName", "LocationType", "AddressLine1", "City", "StateProvince", "CountryCode", "PostalCode", "Region", "Latitude", "Longitude", "ActiveFlag"], locations, 100)
        write_values_insert(handle, "src.Carrier", ["CarrierCode", "SCACCode", "CarrierName", "CarrierMode", "CarrierTier", "HomeCity", "HomeStateProvince", "ActiveFlag"], carriers, 100)
        write_join_insert(handle, "src.Route", ["RouteCode", "OriginLocationID", "DestinationLocationID", "RouteType", "StandardDistanceMiles", "StandardTransitHours", "ActiveFlag", "EffectiveStartDate"], ["RouteCode", "OriginLocationCode", "DestinationLocationCode", "RouteType", "StandardDistanceMiles", "StandardTransitHours", "ActiveFlag", "EffectiveStartDate"], routes, 100, ["v.RouteCode", "origin_location.LocationID", "destination_location.LocationID", "v.RouteType", "v.StandardDistanceMiles", "v.StandardTransitHours", "v.ActiveFlag", "CAST(v.EffectiveStartDate AS date)"], "INNER JOIN src.Location AS origin_location\n    ON v.OriginLocationCode = origin_location.LocationCode\nINNER JOIN src.Location AS destination_location\n    ON v.DestinationLocationCode = destination_location.LocationCode\n")
        write_join_insert(handle, "src.Shipment", ["ShipmentNumber", "CarrierID", "RouteID", "OriginLocationID", "DestinationLocationID", "CustomerReferenceNumber", "ServiceLevel", "CurrentStatus", "ShipmentCreateDateTime", "PlannedPickupDateTime", "ActualPickupDateTime", "PlannedDeliveryDateTime", "ActualDeliveryDateTime", "WeightLbs", "PieceCount", "ShipmentRevenue", "ShipmentCost", "PlannedDistanceMiles", "ActualDistanceMiles", "SourceModifiedAt"], ["ShipmentNumber", "CarrierCode", "RouteCode", "OriginLocationCode", "DestinationLocationCode", "CustomerReferenceNumber", "ServiceLevel", "CurrentStatus", "ShipmentCreateDateTime", "PlannedPickupDateTime", "ActualPickupDateTime", "PlannedDeliveryDateTime", "ActualDeliveryDateTime", "WeightLbs", "PieceCount", "ShipmentRevenue", "ShipmentCost", "PlannedDistanceMiles", "ActualDistanceMiles", "SourceModifiedAt"], shipments, 400, ["v.ShipmentNumber", "carrier.CarrierID", "route.RouteID", "origin_location.LocationID", "destination_location.LocationID", "v.CustomerReferenceNumber", "v.ServiceLevel", "v.CurrentStatus", "CAST(v.ShipmentCreateDateTime AS datetime2(0))", "CAST(v.PlannedPickupDateTime AS datetime2(0))", "CAST(v.ActualPickupDateTime AS datetime2(0))", "CAST(v.PlannedDeliveryDateTime AS datetime2(0))", "CAST(v.ActualDeliveryDateTime AS datetime2(0))", "v.WeightLbs", "v.PieceCount", "v.ShipmentRevenue", "v.ShipmentCost", "v.PlannedDistanceMiles", "v.ActualDistanceMiles", "CAST(v.SourceModifiedAt AS datetime2(0))"], "INNER JOIN src.Carrier AS carrier\n    ON v.CarrierCode = carrier.CarrierCode\nINNER JOIN src.Route AS route\n    ON v.RouteCode = route.RouteCode\nINNER JOIN src.Location AS origin_location\n    ON v.OriginLocationCode = origin_location.LocationCode\nINNER JOIN src.Location AS destination_location\n    ON v.DestinationLocationCode = destination_location.LocationCode\n")
        write_join_insert(handle, "src.Shipment_Status_History", ["ShipmentID", "EventSequenceNumber", "StatusCode", "StatusDescription", "EventDateTime", "LocationID", "ScanType", "EventSource", "ExceptionCode", "Notes"], ["ShipmentNumber", "EventSequenceNumber", "StatusCode", "StatusDescription", "EventDateTime", "LocationCode", "ScanType", "EventSource", "ExceptionCode", "Notes"], scan_events, 1000, ["shipment.ShipmentID", "v.EventSequenceNumber", "v.StatusCode", "v.StatusDescription", "CAST(v.EventDateTime AS datetime2(0))", "location.LocationID", "v.ScanType", "v.EventSource", "v.ExceptionCode", "v.Notes"], "INNER JOIN src.Shipment AS shipment\n    ON v.ShipmentNumber = shipment.ShipmentNumber\nLEFT JOIN src.Location AS location\n    ON v.LocationCode = location.LocationCode\n")
        write_join_insert(handle, "src.Delivery_Exception", ["ShipmentID", "ExceptionCode", "ExceptionDescription", "ExceptionCategory", "SeverityCode", "ExceptionStatus", "ExceptionDateTime", "ResolvedDateTime", "DelayMinutesImpact", "ResponsibleParty", "Notes"], ["ShipmentNumber", "ExceptionCode", "ExceptionDescription", "ExceptionCategory", "SeverityCode", "ExceptionStatus", "ExceptionDateTime", "ResolvedDateTime", "DelayMinutesImpact", "ResponsibleParty", "Notes"], delivery_exceptions, 500, ["shipment.ShipmentID", "v.ExceptionCode", "v.ExceptionDescription", "v.ExceptionCategory", "v.SeverityCode", "v.ExceptionStatus", "CAST(v.ExceptionDateTime AS datetime2(0))", "CAST(v.ResolvedDateTime AS datetime2(0))", "v.DelayMinutesImpact", "v.ResponsibleParty", "v.Notes"], "INNER JOIN src.Shipment AS shipment\n    ON v.ShipmentNumber = shipment.ShipmentNumber\n")
        handle.write("SELECT\n    (SELECT COUNT(*) FROM src.Location) AS LocationCount,\n    (SELECT COUNT(*) FROM src.Carrier) AS CarrierCount,\n    (SELECT COUNT(*) FROM src.Route) AS RouteCount,\n    (SELECT COUNT(*) FROM src.Shipment) AS ShipmentCount,\n    (SELECT COUNT(*) FROM src.Shipment_Status_History) AS ShipmentStatusHistoryCount,\n    (SELECT COUNT(*) FROM src.Delivery_Exception) AS DeliveryExceptionCount;\nGO\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic transportation warehouse source data.")
    parser.add_argument("--output-dir", default="data/generated", help="Directory for warehouse-compatible generated CSV files.")
    parser.add_argument("--raw-output-dir", default="data/raw", help="Directory for source-system raw CSV files.")
    parser.add_argument("--shipments", type=int, default=10000, help="Number of shipment rows to generate.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducible output.")
    parser.add_argument("--sql-seed-path", default="sql/source/02_seed_source_data.sql", help="SQL seed script output path.")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    generated_output_dir = Path(args.output_dir)
    raw_output_dir = Path(args.raw_output_dir)
    sql_seed_path = Path(args.sql_seed_path)

    carriers = build_carriers()
    locations = build_locations()
    routes = build_routes(rng)
    exception_codes = build_exception_codes()
    shipments, scan_events, delivery_exceptions = generate_source_data(carriers, locations, routes, exception_codes, args.shipments, rng)

    write_csv(generated_output_dir / "carriers.csv", build_warehouse_carriers(carriers))
    write_csv(generated_output_dir / "locations.csv", build_warehouse_locations(locations))
    write_csv(generated_output_dir / "routes.csv", build_warehouse_routes(routes))
    write_csv(generated_output_dir / "shipments.csv", build_warehouse_shipments(shipments))
    write_csv(generated_output_dir / "delivery_exceptions.csv", build_warehouse_delivery_exceptions(delivery_exceptions))

    write_csv(raw_output_dir / "carrier_lookup.csv", carriers)
    write_csv(raw_output_dir / "locations.csv", locations)
    write_csv(raw_output_dir / "routes.csv", routes)
    write_csv(raw_output_dir / "shipments.csv", shipments)
    write_csv(raw_output_dir / "daily_delivery_scan_events.csv", scan_events)
    write_csv(raw_output_dir / "delivery_exceptions.csv", delivery_exceptions)
    write_csv(raw_output_dir / "exception_code_lookup.csv", build_exception_code_lookup(exception_codes))
    write_csv(raw_output_dir / "route_distance_reference.csv", build_route_distance_reference(routes))

    write_sql_seed(sql_seed_path, carriers, locations, routes, shipments, scan_events, delivery_exceptions)

    print(f"Warehouse-compatible files generated in {generated_output_dir.resolve()}")
    print(f"Source raw files generated in {raw_output_dir.resolve()}")
    print(f"SQL seed script generated at {sql_seed_path.resolve()}")
    print(f"Carriers: {len(carriers)}")
    print(f"Locations: {len(locations)}")
    print(f"Routes: {len(routes)}")
    print(f"Shipments: {len(shipments)}")
    print(f"Daily scan events: {len(scan_events)}")
    print(f"Delivery exceptions: {len(delivery_exceptions)}")


if __name__ == "__main__":
    main()
