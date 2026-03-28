import json
import urllib3
import os

http = urllib3.PoolManager()

def lambda_handler(event, context):
    SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL')
    message = json.loads(event['Records'][0]['Sns']['Message'])
    
    alarm_name = message.get('AlarmName', 'Unknown')
    alarm_state = message.get('StateValue', 'UNKNOWN')
    state_reason = message.get('StateReason', '')
    
    color = '#FF0000' if alarm_state == 'ALARM' else '#00FF00'
    
    slack_message = {
        'attachments': [{
            'color': color,
            'title': f'🚨 {alarm_name}',
            'text': state_reason,
            'fields': [{'title': 'State', 'value': alarm_state, 'short': True}]
        }]
    }
    
    encoded_msg = json.dumps(slack_message).encode('utf-8')
    resp = http.request('POST', SLACK_WEBHOOK_URL, body=encoded_msg)
    
    return {'statusCode': 200, 'body': 'Alert sent to Slack!'}
