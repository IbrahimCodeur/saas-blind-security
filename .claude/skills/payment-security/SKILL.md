---
name: payment-security
description: Secure payments and billing in a SaaS — webhook signature verification and replay protection, server-side prices and plans, idempotency, entitlement only after confirmed payment, refunds, quotas and PCI scope reduction (Stripe, PayPal, Paddle, Mollie, Laravel Cashier and similar).
---

# Payment security

Part of saas-blind-security — created and maintained by IbrahimCodeur.

## Objectives

- Nobody can obtain paid features, credits or refunds without a real, confirmed payment.
- Webhooks cannot be forged or replayed; payment data never touches your servers unnecessarily.

## Steps

1. **Map the money flow**: checkout creation, client confirmation, provider webhooks, subscription changes
   (upgrade/downgrade/cancel), trials, coupons, credits/usage billing, invoices, refunds, chargebacks, plan
   limits enforcement.
2. **Server-side pricing.** Amount, currency, plan, quantity and coupon are computed on the server from IDs
   (e.g. Stripe Price IDs), never trusted from the client. Coupon validity/usage limits checked server-side.
3. **Webhook authenticity.** Verify signatures with the provider SDK on the **raw** body:
   Stripe `stripe.webhooks.constructEvent(rawBody, sigHeader, endpointSecret)` / `\Stripe\Webhook::constructEvent`
   (Cashier verifies when `STRIPE_WEBHOOK_SECRET` is set), PayPal webhook signature verification API,
   Paddle signature header. Semgrep lead: `sbs-js-stripe-webhook-unverified`. Reject on failure with 400.
4. **Replay & ordering.** Store processed event IDs (idempotency), rely on the provider's timestamp tolerance,
   handle out-of-order events, re-fetch the object from the provider API when state matters.
5. **Entitlements.** Grant access only on confirmed events (e.g. `checkout.session.completed` with
   `payment_status=paid`, `invoice.paid`), not on the success redirect page. Revoke on failed payment /
   cancellation / refund / dispute according to policy.
6. **Race conditions.** Use DB transactions and unique constraints/locks for credits, balances, coupon
   redemptions and order fulfilment; idempotency keys for API calls to the provider.
7. **Quotas & limits.** Plan limits (seats, projects, API calls, storage) enforced server-side at each
   creating action and in background jobs; downgrades handled.
8. **PCI scope.** Use hosted fields/checkout (Stripe Elements/Checkout, PayPal buttons); never log or store
   PAN/CVV; secrets (`sk_live_…`, webhook secrets) only in environment/secret manager; restricted API keys.
9. **Tenant binding.** Customer/subscription IDs mapped to the right tenant; webhook handlers look up the
   tenant from the provider object, not from user input.

## Security rules

- Never run real charges or refunds; use the provider's test mode and test keys only, with the user's approval.
- Never print API keys or webhook secrets; recommend rotation if exposed.
- Any webhook without signature verification is at least HIGH.

## Validation criteria

- [ ] Tests: unsigned/forged webhook rejected; duplicate event processed once; client-modified price ignored;
      access not granted from the success URL alone; concurrent coupon redemption cannot exceed limits.
- [ ] Entitlement state machine documented (paid, past_due, canceled, refunded, disputed).
- [ ] No card data stored or logged.
