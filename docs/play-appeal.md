# Play Console appeal — Play Console Requirements (org account)

Draft appeal for the July 2026 rejection of `com.omnia.wallet` under the
**Play Console Requirements** policy (organization-account requirement for
financial services / cryptocurrency software wallets).

**Before submitting this appeal**, apply the listing corrections in
[`play-store-listing.md`](./play-store-listing.md): category **Tools** (not
Finance), remove the `crypto` tag, remove all "payment"/"get paid" language,
and answer the Financial features declaration as *no financial features*.
The appeal is far stronger once the declarations already match the argument.

Fill the bracketed fields before sending. Keep it factual and short —
reviewers read many of these.

---

## Appeal text

> **App:** Omnia (`com.omnia.wallet`)
> **Issue:** Play Console Requirements — organization account required
>
> Thank you for the review. We believe the app was classified as a
> cryptocurrency software wallet, and we would like to provide details
> showing it does not provide financial products or services. We have also
> corrected our own store declarations, which we accept were the source of
> the confusion.
>
> **What the app is.** Omnia is the open-source client for the Omnia
> Protocol, a public-domain (CC0) coordination network. Its two functions are
> (1) holding a self-sovereign identity — a `did:omnia:` decentralized
> identifier derived from a key generated on the device — and (2) displaying
> and using **Universal Basic Compute (UBC)**, the user's monthly quota for
> submitting work to the network.
>
> **UBC is not a currency or a financial instrument.** Specifically:
>
> - **It cannot be purchased.** There is no way to acquire UBC with money.
>   It is granted automatically to every registered identity as a fixed
>   monthly allowance (1,000 UBC per epoch).
> - **It cannot be sold, traded, or exchanged.** UBC is *soulbound* —
>   permanently bound to a single identity by protocol rule. There is no
>   exchange, no market, no order book, no liquidity pool, and no price.
> - **It has no monetary value and no fiat rails.** The app contains no
>   on-ramp, off-ramp, payment processor, or means of conversion to any
>   currency.
> - **Transfers are not payments.** Allocating UBC to another identity
>   **burns** it from the sender's quota; the recipient identity is recorded
>   for provenance and **is not credited a balance**. This is stated
>   in-app on every transaction detail screen. Because value is destroyed
>   rather than moved, the operation cannot function as a payment,
>   remittance, or transfer of value.
> - **There are no in-app purchases, no ads, and no monetization** of any
>   kind. The app is free and the protocol is public domain.
>
> UBC is best understood as a metered compute allowance — closer to an API
> rate limit or a monthly data quota than to money. The protocol's stated
> purpose for this design is to avoid speculation and wealth concentration
> entirely.
>
> **Corrections we have made.** We accept that our original listing invited
> the classification, and we have corrected it to accurately describe the
> app:
>
> - Primary category changed from **Finance** to **Tools**.
> - Removed the `crypto` tag.
> - Removed all "payment" and "get paid" wording, which was inaccurate given
>   the burn semantics above.
> - Financial features declaration answered as **no financial features**.
> - The listing now states plainly that UBC is a soulbound compute credit
>   that cannot be bought, sold, or exchanged and has no monetary value.
>
> **Supporting references**
>
> - Terms of use (UBC is not money):
>   https://willow7737.github.io/omnia-web/wallet/terms/
> - Privacy policy:
>   https://willow7737.github.io/omnia-web/wallet/privacy/
> - Account deletion:
>   https://willow7737.github.io/omnia-web/wallet/delete-account/
> - Protocol source (public domain, CC0):
>   https://github.com/Willow7737/omnia-protocol
> - App source: https://github.com/Willow7737/Omnia-Wallet
>
> We are happy to provide a demo walkthrough or test credentials if that
> helps the review. If you nonetheless determine that holding self-custody
> keys places the app in the organization-only category, please let us know
> and we will complete organization registration rather than contest it.
>
> Thank you for your time.
>
> [Your name]
> [Entity name, if applicable]

---

## Honest odds, and what to do in parallel

This is a genuine argument, not a workaround — UBC really is
non-purchasable, non-tradeable, and destroyed on transfer, so the app really
does not provide a financial service.

But be realistic: the app holds self-custody cryptographic keys for a
distributed ledger and has send/receive/balance/QR flows. Reviewers pattern
match on that shape, and Play has been widening rather than narrowing this
category. The appeal is worth filing — it is free and may resolve in ~7 days —
but **do not treat it as the plan.**

**Start the D-U-N-S application the same day you file the appeal.** It takes
roughly 30 days and gates organization registration, which is the only
outcome that settles this permanently. See the "Organization account"
section of [`play-store-listing.md`](./play-store-listing.md).

## What not to do

Do not attempt to disguise what the app does — do not hide the key handling,
remove the disclosure that keys are stored on-device, or misstate the
Financial features declaration to get past review. Everything above works
because it is true. Misrepresenting an app's features is itself a Play
Console Requirements violation and risks the developer account, which is a
far worse outcome than a 30-day wait.
