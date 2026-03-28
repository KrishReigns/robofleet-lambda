#!/usr/bin/env python3
"""
Generate sample telemetry data for RoboFleet Lambda testing
Creates realistic device telemetry matching the analytics report structure
"""

import json
import random
from datetime import datetime, timedelta

# Constants
DEVICES = [f"ROBOT-{i:04d}" for i in range(1, 21)]  # ROBOT-0001 to ROBOT-0020
FLEETS = ["FLEET-BOSTON-01", "FLEET-BOSTON-02", "FLEET-SEATTLE-01"]
ZONES = [f"ZONE-{chr(65 + i)}" for i in range(5)]  # ZONE-A to ZONE-E
STATUSES = ["ACTIVE", "IDLE", "CHARGING", "ERROR"]
ERROR_CODES = ["ERR_SENSOR", "ERR_BATTERY", "ERR_MOTOR", "ERR_COMM"]

# Device-to-fleet mapping
DEVICE_TO_FLEET = {
    "ROBOT-0001": "FLEET-BOSTON-01", "ROBOT-0002": "FLEET-BOSTON-02",
    "ROBOT-0003": "FLEET-BOSTON-01", "ROBOT-0004": "FLEET-BOSTON-02",
    "ROBOT-0005": "FLEET-BOSTON-02", "ROBOT-0006": "FLEET-BOSTON-01",
    "ROBOT-0007": "FLEET-BOSTON-02", "ROBOT-0008": "FLEET-SEATTLE-01",
    "ROBOT-0009": "FLEET-BOSTON-02", "ROBOT-0010": "FLEET-BOSTON-02",
    "ROBOT-0011": "FLEET-BOSTON-02", "ROBOT-0012": "FLEET-SEATTLE-01",
    "ROBOT-0013": "FLEET-BOSTON-02", "ROBOT-0014": "FLEET-BOSTON-01",
    "ROBOT-0015": "FLEET-SEATTLE-01", "ROBOT-0016": "FLEET-SEATTLE-01",
    "ROBOT-0017": "FLEET-SEATTLE-01", "ROBOT-0018": "FLEET-BOSTON-02",
    "ROBOT-0019": "FLEET-SEATTLE-01", "ROBOT-0020": "FLEET-BOSTON-01"
}

def generate_telemetry(num_records=500):
    """Generate sample telemetry records"""
    records = []
    base_time = datetime(2026, 3, 20, 0, 0, 0)
    
    for i in range(num_records):
        device = random.choice(DEVICES)
        fleet = DEVICE_TO_FLEET[device]
        timestamp = base_time + timedelta(
            hours=random.randint(0, 144),  # 6 days of data
            minutes=random.randint(0, 59),
            seconds=random.randint(0, 59)
        )
        
        # Determine status with realistic distribution
        status = random.choices(
            STATUSES,
            weights=[40, 35, 15, 10]  # ACTIVE 40%, IDLE 35%, CHARGING 15%, ERROR 10%
        )[0]
        
        # Battery level depends on status
        if status == "CHARGING":
            battery = random.randint(50, 100)
        elif status == "ERROR":
            battery = random.randint(5, 40)  # Errors often with low battery
        else:
            battery = random.randint(20, 95)
        
        # Speed depends on status
        if status == "ACTIVE":
            speed = round(random.uniform(0.5, 3.5), 2)
        else:
            speed = 0.0
        
        record = {
            "device_id": device,
            "fleet_id": fleet,
            "timestamp": timestamp.isoformat() + "Z",
            "location_zone": random.choice(ZONES),
            "battery_level": battery,
            "status": status,
            "speed": speed
        }
        
        # Add error code if status is ERROR
        if status == "ERROR":
            record["error_code"] = random.choice(ERROR_CODES)
        
        records.append(record)
    
    return records

def save_jsonlines(records, filename):
    """Save records as JSON Lines format (one JSON object per line)"""
    with open(filename, 'w') as f:
        for record in records:
            f.write(json.dumps(record) + '\n')

def save_json(records, filename):
    """Save records as JSON array"""
    with open(filename, 'w') as f:
        json.dump(records, f, indent=2)

if __name__ == "__main__":
    print("Generating 500 sample telemetry records...")
    records = generate_telemetry(500)
    
    # Save in both formats
    save_jsonlines(records, "sample_telemetry.jsonl")
    save_json(records, "sample_telemetry.json")
    
    print(f"✓ Generated {len(records)} telemetry records")
    print(f"✓ Saved: sample_telemetry.jsonl (streaming format)")
    print(f"✓ Saved: sample_telemetry.json (array format)")
    print("\nFirst 3 records:")
    for i, record in enumerate(records[:3]):
        print(f"  {i+1}. {json.dumps(record)}")
