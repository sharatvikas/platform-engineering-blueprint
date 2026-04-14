# Runbook: ${{ values.name }}

**Service:** ${{ values.name }}  
**Team:** ${{ values.team }}  
**Tier:** ${{ values.tier }}  
**SLO:** ${{ values.availability_target }}% availability, p99 ≤ ${{ values.latency_p99_ms }}ms  

---

## Overview

${{ values.description }}

**Quick links:**
- [Grafana Dashboard](#) — TODO: add link after deploying dashboard
- [PagerDuty Service](#) — TODO: add PagerDuty service URL
- [Logs (Loki/CloudWatch)](#) — TODO: add log link

---

## Alert: HighErrorRate

**Firing condition:** Error rate > 1% for 5 minutes  
**Severity:** ${{ 'critical' if values.tier == 'tier1' else 'warning' }}  

### Diagnosis

1. Check current error rate:
   ```
   sum(rate(http_requests_total{job="${{ values.name }}",status=~"5.."}[5m])) 
   / sum(rate(http_requests_total{job="${{ values.name }}"}[5m]))
   ```

2. Check which endpoints are erroring:
   ```
   topk(5, sum by (path,status) (rate(http_requests_total{job="${{ values.name }}",status=~"5.."}[5m])))
   ```

3. Check pod logs:
   ```bash
   kubectl logs -n ${{ values.namespace }} -l app=${{ values.name }} --tail=100 --since=5m
   ```

4. Check recent deployments:
   ```bash
   kubectl rollout history deployment/${{ values.name }} -n ${{ values.namespace }}
   ```

### Remediation

| Action | Command |
|--------|---------|
| Check pod health | `kubectl get pods -n ${{ values.namespace }} -l app=${{ values.name }}` |
| Describe failing pods | `kubectl describe pod -n ${{ values.namespace }} -l app=${{ values.name }}` |
| Roll back last deploy | `kubectl rollout undo deployment/${{ values.name }} -n ${{ values.namespace }}` |
| Scale up replicas | `kubectl scale deployment/${{ values.name }} -n ${{ values.namespace }} --replicas=5` |

---

## Alert: HighLatency

**Firing condition:** p99 latency > ${{ values.latency_p99_ms }}ms for 5 minutes  
**Severity:** warning  

### Diagnosis

1. Check latency histogram:
   ```
   histogram_quantile(0.99, sum by (le,path) (rate(http_request_duration_seconds_bucket{job="${{ values.name }}"}[5m])))
   ```

2. Check downstream dependencies:
   - Database connection pool exhaustion?
   - External API timeouts?
   - CPU throttling? (`container_cpu_cfs_throttled_seconds_total`)

3. Check resource usage:
   ```bash
   kubectl top pods -n ${{ values.namespace }} -l app=${{ values.name }}
   ```

### Remediation

| Action | Command |
|--------|---------|
| Increase CPU limits | Edit deployment resources.limits.cpu |
| Enable HPA | `kubectl autoscale deployment/${{ values.name }} -n ${{ values.namespace }} --cpu-percent=70 --min=2 --max=10` |
| Enable DB connection pool tuning | Set `DB_MAX_CONNECTIONS` env var |

---

## Alert: SLOBurnRateHigh (Tier ${{ '1' if values.tier == 'tier1' else '2+' }} fast burn)

**Firing condition:** Error budget consuming at 14× rate (1h+5m window)  
**Severity:** critical (page immediately)

### Diagnosis

1. Check error budget remaining:
   ```
   1 - (
     sum(increase(http_requests_total{job="${{ values.name }}",status=~"5.."}[${{ values.error_budget_window_days }}d]))
     / sum(increase(http_requests_total{job="${{ values.name }}"}[${{ values.error_budget_window_days }}d]))
   ) / (1 - ${{ values.availability_target / 100 }})
   ```

2. Check both fast windows (1h and 5m) to confirm the burn is real, not a spike.

3. **If error budget is < 10% remaining:** consider freezing non-critical deploys for this service.

### Remediation

1. Identify root cause from the HighErrorRate runbook section above
2. Declare an incident in PagerDuty and loop in the team
3. After resolving, conduct a blameless postmortem
4. Document the incident and update this runbook with new failure modes

---

## Escalation

| Tier | On-call | Escalation |
|------|---------|-----------|
| P1 (Critical) | ${{ values.team }}-oncall | Escalate to ${{ values.team }}-lead after 15 min |
| P2 (Warning) | ${{ values.team }}-oncall | Resolve within 4h or escalate |

**Slack:** ${{ values.slack_channel }}  
**PagerDuty:** ${{ values.team }}-escalation-policy  

---

*This runbook was auto-generated from the SRE Service Template. Keep it updated as the service evolves.*  
*Last generated: ${{ '' | now }}*
