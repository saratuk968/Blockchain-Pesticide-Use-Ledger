(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALERT_EXISTS (err u303))

(define-data-var next-alert-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map alert-subscriptions
    { subscriber: principal, farm-id: uint }
    { alert-types: (list 10 (string-ascii 30)), active: bool }
)

(define-map active-alerts
    { alert-id: uint }
    {
        farm-id: uint,
        alert-type: (string-ascii 30),
        severity: (string-ascii 10),
        message: (string-ascii 200),
        triggered-date: uint,
        resolved: bool,
        application-id: (optional uint)
    }
)

(define-map farm-alerts
    { farm-id: uint }
    { alert-ids: (list 100 uint) }
)

(define-public (subscribe-to-alerts (farm-id uint) (alert-types (list 10 (string-ascii 30))))
    (begin
        (asserts! (> (len alert-types) u0) ERR_INVALID_INPUT)
        (map-set alert-subscriptions
            { subscriber: tx-sender, farm-id: farm-id }
            { alert-types: alert-types, active: true }
        )
        (ok true)
    )
)

(define-public (create-pre-harvest-alert (farm-id uint) (application-id uint) (days-remaining uint))
    (let
        (
            (alert-id (var-get next-alert-id))
            (current-alerts (default-to (list) (get alert-ids (map-get? farm-alerts { farm-id: farm-id }))))
            (severity (if (<= days-remaining u3) "high" (if (<= days-remaining u7) "medium" "low")))
            (message (concat "Pre-harvest interval: " (int-to-ascii (to-int days-remaining))))
        )
        (map-set active-alerts
            { alert-id: alert-id }
            {
                farm-id: farm-id,
                alert-type: "pre-harvest-warning",
                severity: severity,
                message: message,
                triggered-date: stacks-block-height,
                resolved: false,
                application-id: (some application-id)
            }
        )
        (map-set farm-alerts
            { farm-id: farm-id }
            { alert-ids: (unwrap! (as-max-len? (append current-alerts alert-id) u100) ERR_INVALID_INPUT) }
        )
        (var-set next-alert-id (+ alert-id u1))
        (ok alert-id)
    )
)

(define-public (create-compliance-alert (farm-id uint) (alert-message (string-ascii 200)))
    (let
        (
            (alert-id (var-get next-alert-id))
            (current-alerts (default-to (list) (get alert-ids (map-get? farm-alerts { farm-id: farm-id }))))
        )
        (map-set active-alerts
            { alert-id: alert-id }
            {
                farm-id: farm-id,
                alert-type: "compliance-violation",
                severity: "high",
                message: alert-message,
                triggered-date: stacks-block-height,
                resolved: false,
                application-id: none
            }
        )
        (map-set farm-alerts
            { farm-id: farm-id }
            { alert-ids: (unwrap! (as-max-len? (append current-alerts alert-id) u100) ERR_INVALID_INPUT) }
        )
        (var-set next-alert-id (+ alert-id u1))
        (ok alert-id)
    )
)

(define-public (resolve-alert (alert-id uint))
    (let
        (
            (alert-data (unwrap! (map-get? active-alerts { alert-id: alert-id }) ERR_NOT_FOUND))
        )
        (map-set active-alerts
            { alert-id: alert-id }
            (merge alert-data { resolved: true })
        )
        (ok true)
    )
)

(define-read-only (get-farm-alerts (farm-id uint))
    (map-get? farm-alerts { farm-id: farm-id })
)

(define-read-only (get-alert-details (alert-id uint))
    (map-get? active-alerts { alert-id: alert-id })
)

(define-read-only (get-active-alerts (farm-id uint))
    (let
        (
            (alerts (default-to (list) (get alert-ids (map-get? farm-alerts { farm-id: farm-id }))))
        )
        (fold filter-active-alerts alerts (list))
    )
)

(define-private (filter-active-alerts (alert-id uint) (acc (list 100 uint)))
    (let
        (
            (alert-data (map-get? active-alerts { alert-id: alert-id }))
        )
        (if (and (is-some alert-data) (not (get resolved (unwrap-panic alert-data))))
            (unwrap! (as-max-len? (append acc alert-id) u100) acc)
            acc
        )
    )
)

(define-read-only (get-high-severity-alerts (farm-id uint))
    (let
        (
            (alerts (default-to (list) (get alert-ids (map-get? farm-alerts { farm-id: farm-id }))))
        )
        (fold filter-high-severity alerts (list))
    )
)

(define-private (filter-high-severity (alert-id uint) (acc (list 100 uint)))
    (let
        (
            (alert-data (map-get? active-alerts { alert-id: alert-id }))
        )
        (if (and (is-some alert-data) 
                 (not (get resolved (unwrap-panic alert-data)))
                 (is-eq (get severity (unwrap-panic alert-data)) "high"))
            (unwrap! (as-max-len? (append acc alert-id) u100) acc)
            acc
        )
    )
)
