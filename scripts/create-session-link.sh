#!/usr/bin/env bash
#
# Create a live Stripe Payment Link for ONE caregiver community session.
#
# Why one link per session date:
#   A Payment Link has no concept of capacity. The only cap Stripe offers is
#   restrictions[completed_sessions][limit], which is a LIFETIME limit on the
#   link -- not a per-date limit. So an evergreen link cannot express
#   "12 seats each Tuesday". One link per date can.
#
# Why quantity is fixed at 1:
#   completed_sessions counts CHECKOUTS, not seats. If buyers could purchase
#   3 seats in one checkout, a limit of 12 would admit up to 36 people. Fixing
#   quantity at 1 makes one checkout equal one seat, so the limit is a real
#   capacity control. It also means every attendee gets named individually.
#
# When the seat limit is reached, Stripe deactivates the link automatically and
# shows the sold-out message below.
#
# Usage:
#   ./scripts/create-session-link.sh "2026-09-15 (Tue 7pm CT)" 12
#
# Requires: stripe CLI authenticated, live context.
#   stripe switch context acct_1U9mTAGIeQDVGKRc --live

set -euo pipefail

SESSION_DATE="${1:?usage: create-session-link.sh \"<session date label>\" <seats>}"
SEATS="${2:?usage: create-session-link.sh \"<session date label>\" <seats>}"

# Caregiver Community Sessions, $110 one-time (live)
PRICE_ID="price_1UAIliGIeQDVGKRc5wU5QKpP"
REDIRECT_URL="https://rangeassociates.com/payments/thank-you/"

stripe payment_links create --live \
  -d "line_items[0][price]=${PRICE_ID}" \
  -d "line_items[0][quantity]=1" \
  -d "restrictions[completed_sessions][limit]=${SEATS}" \
  -d "inactive_message=This session is full. Email hello@rangeassociates.com and we'll add you to the next one." \
  -d "payment_method_types[0]=card" \
  -d "payment_method_types[1]=cashapp" \
  -d "custom_fields[0][key]=participantname" \
  -d "custom_fields[0][label][type]=custom" \
  -d "custom_fields[0][label][custom]=Participant name" \
  -d "custom_fields[0][type]=text" \
  -d "metadata[session_date]=${SESSION_DATE}" \
  -d "metadata[seats]=${SEATS}" \
  -d "after_completion[type]=redirect" \
  -d "after_completion[redirect][url]=${REDIRECT_URL}" \
| python3 -c "
import sys, json
raw = sys.stdin.read(); i = raw.find('{')
d = json.loads(raw[i:])
if 'error' in d:
    print('ERROR:', d['error'].get('message')); sys.exit(1)
print('session : ' + d['metadata'].get('session_date', ''))
print('seats   : ' + d['metadata'].get('seats', ''))
print('url     : ' + d['url'])
print('id      : ' + d['id'])
"
