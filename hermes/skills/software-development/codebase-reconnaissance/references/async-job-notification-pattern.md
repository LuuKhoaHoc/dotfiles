# Async Job Pattern — API Trigger + WebSocket Notification + Data Refresh

## Overview

Pattern for triggering a heavy backend computation from the frontend without blocking the UI.
The API returns immediately (the backend queues the job), and completion is signaled via
a WebSocket notification dispatched as a browser CustomEvent. A fallback timeout ensures the
loading state resolves even if the notification never arrives.

Canonical implementation: `PayrollPeriodDetailView.tsx` — payroll run calculation.

## Pattern Diagram

```
[User clicks Calculate]
        │
        ▼
 POST /hr/payroll/runs/{id}/calculate
        │
        ▼  (returns immediately with { success, data })
   ┌─────┴─────┐
   │ success   │  !success → show error toast → set isRefreshing=false
   └─────┬─────┘
         │
    [Show loading toast]
    [Schedule 30s fallback timeout]
         │
         ▼
    ┌────────────┐
    │ WebSocket  │  ←─── Backend sends NOTIFICATION
    │ connection │       { eventType: 'hr.payroll.run.calculation.succeeded'
    │            │         payload: { payrollRunId } }
    └─────┬──────┘
          │
    dispatchNotificationBrowserEvent(notification)
          │
          ▼
    window.addEventListener('hilo:notification', handler)
          │
    ┌─────┴─────┐
    │ SUCCEEDED │  FAILED or fallback timeout
    └─────┬─────┘
          │
    dismissCalculationToast()
    refreshPayrollCalculationData()  // parallel: period detail + employee list
    setIsRefreshingPayrollRun(false)
          │
          ▼
    [UI updates with fresh data]
```

## Key Implementation Details

### State Variables

```ts
const [isRefreshingPayrollRun, setIsRefreshingPayrollRun] = useState(false);
const calculationFallbackTimeoutRef = useRef<number | null>(null);
const calculationToastIdRef = useRef<string | number | null>(null);
```

### Trigger Handler

```ts
const handleCalculatePayrollRun = async () => {
  setIsRefreshingPayrollRun(true);
  dismissCalculationToast();

  // Show loading toast (never auto-dismisses — we control it)
  calculationToastIdRef.current = toast.loading(
    t('features.salary.payrollDetail.actions.calculating'),
    { duration: Infinity },
  );

  try {
    const response = await calculatePayrollRunMutation.mutateAsync(payrollPeriod.id);

    if (!response.success) {
      dismissCalculationToast();
      toast.error(/* error message */);
      setIsRefreshingPayrollRun(false);
      return;
    }

    if (isPayrollCalculationFailed(response.data)) {
      dismissCalculationToast();
      toast.error(/* failure message */);
      setIsRefreshingPayrollRun(false);
      return;
    }

    // Keep the loading toast alive until the WebSocket notification fires
    scheduleCalculationFallbackTimeout();
  } catch (error) {
    dismissCalculationToast();
    toast.error(/* error message */);
    clearCalculationFallbackTimeout();
    setIsRefreshingPayrollRun(false);
  }
};
```

### Notification Listener

```ts
useEffect(() => {
  const handleNotification = (event: Event) => {
    if (!isNotificationBrowserEvent(event)) return;
    if (!isRefreshingPayrollRun) return;

    const notification = event.detail;
    const isSucceeded = isPayrollCalculationSucceededNotification(notification, payrollPeriod.id);
    const isFailed = isPayrollCalculationFailedNotification(notification, payrollPeriod.id);

    if (isSucceeded || isFailed) {
      void completePayrollCalculationLoading();
    }
  };

  window.addEventListener(NOTIFICATION_BROWSER_EVENT_NAME, handleNotification);
  return () => window.removeEventListener(NOTIFICATION_BROWSER_EVENT_NAME, handleNotification);
}, [completePayrollCalculationLoading, isRefreshingPayrollRun, payrollPeriod.id]);
```

### Completion Handler

```ts
const completePayrollCalculationLoading = useCallback(async () => {
  clearCalculationFallbackTimeout();
  dismissCalculationToast();
  await refreshPayrollCalculationData(); // parallel: period detail + employee list
  setIsRefreshingPayrollRun(false);
}, [clearCalculationFallbackTimeout, dismissCalculationToast, refreshPayrollCalculationData]);
```

### Fallback Timeout (30s default)

```ts
const PAYROLL_CALCULATION_FALLBACK_TIMEOUT_MS = 30_000;

const scheduleCalculationFallbackTimeout = useCallback(() => {
  clearCalculationFallbackTimeout();
  calculationFallbackTimeoutRef.current = window.setTimeout(() => {
    void completePayrollCalculationLoading();
  }, PAYROLL_CALCULATION_FALLBACK_TIMEOUT_MS);
}, [clearCalculationFallbackTimeout, completePayrollCalculationLoading]);
```

### Cleanup on Unmount

```ts
useEffect(() => {
  return () => clearCalculationFallbackTimeout();
}, [clearCalculationFallbackTimeout]);
```

## WebSocket Infrastructure (shared layer)

### Connection Manager (`packages/shared/src/websocket/connection-manager.ts`)

- Singleton `WebSocketManager` via `wsManager = WebSocketManager.getInstance()`
- Connects to `BASE_URL + /notifications/ws`
- Exponential backoff reconnect: 1s base, 30s max, ±25% jitter
- Auto PING → PONG
- Dedup by `sessionNotifiedIds` to avoid duplicate toasts after reconnect replay
- On NOTIFICATION message: adds to `notificationStore`, sends ACK, tracks session-notified, dispatches to handlers

### Browser Event Dispatch (`notification-browser-event.ts`)

```ts
const NOTIFICATION_BROWSER_EVENT_NAME = 'hilo:notification';

export function dispatchNotificationBrowserEvent(notification: Notification) {
  window.dispatchEvent(new CustomEvent(NOTIFICATION_BROWSER_EVENT_NAME, { detail: notification }));
}
```

### Event Types (`NOTIFICATION_EVENT_TYPES`)

```ts
{
  ATTENDANCE_SHEET_REFRESH_RESULT: 'hr.attendance.sheet.refresh.result',
  PAYROLL_RUN_CALCULATION_SUCCEEDED: 'hr.payroll.run.calculation.succeeded',
  PAYROLL_RUN_CALCULATION_FAILED: 'hr.payroll.run.calculation.failed',
}
```

## Mutation Hook Optimization

The mutation hook (at `hooks/use*Queries.ts`) should check `response.success` before invalidating
caches — if the backend job failed, don't invalidate:

```ts
export function useCalculatePayrollRunMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: calculatePayrollRun,
    onSuccess: async (response, id) => {
      const status = response.data?.status?.toLowerCase();
      if (!response.success || status === 'failed') return;  // ← optimization
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: SALARY_FUND_QUERY_KEYS.payrollPeriodDetail(id) }),
        queryClient.invalidateQueries({ queryKey: SALARY_FUND_QUERY_KEYS.root }),
      ]);
    },
  });
}
```

## When to Use This Pattern

- Any heavy backend computation where the user waits for a result
- The backend supports async job processing with WebSocket notification
- The operation takes longer than a normal API call (3+ seconds)
- You need to show a persistent loading state without blocking the UI

## Pitfalls

- **Missing cleanup on unmount** → `clearTimeout` and `removeEventListener` must run in the effect cleanup, or the fallback timeout fires after the component is gone (React state update on unmounted component warning)
- **Missing the notification layer in audit** — the API POST returns instantly while real work completes via WebSocket. Always check for CustomEvent listeners alongside the API call in code audits
- **No fallback timeout** → the loading toast stays forever if the WebSocket notification is lost. Always add a safety net (30s is reasonable for payroll)
- **Not checking `isRefreshingPayrollRun`** → the notification handler fires on any event, even if the user navigated away and came back. The guard prevents stale completions
- **Toast ID tracking** — use a ref (not state) for the toast ID to avoid re-renders and stale closures
