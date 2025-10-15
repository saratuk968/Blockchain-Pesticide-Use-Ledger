(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_INPUT (err u402))
(define-constant ERR_EXPIRED (err u403))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u404))
(define-constant ERR_BATCH_RECALLED (err u405))

(define-data-var next-batch-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map pesticide-batches
    { batch-id: uint }
    {
        owner: principal,
        pesticide-name: (string-ascii 100),
        manufacturer: (string-ascii 100),
        lot-number: (string-ascii 50),
        manufacture-date: uint,
        expiration-date: uint,
        initial-quantity-liters: uint,
        remaining-quantity-liters: uint,
        purchase-date: uint,
        supplier: (string-ascii 100),
        recalled: bool
    }
)

(define-map batch-applications
    { batch-id: uint }
    { application-ids: (list 100 uint) }
)

(define-map application-batches
    { application-id: uint }
    { batch-id: uint, quantity-used: uint }
)

(define-map farm-batches
    { farm-id: uint }
    { batch-ids: (list 100 uint) }
)

(define-public (register-batch (pesticide-name (string-ascii 100)) (manufacturer (string-ascii 100)) (lot-number (string-ascii 50)) (manufacture-date uint) (expiration-date uint) (quantity-liters uint) (supplier (string-ascii 100)))
    (let
        (
            (batch-id (var-get next-batch-id))
        )
        (asserts! (> (len pesticide-name) u0) ERR_INVALID_INPUT)
        (asserts! (> quantity-liters u0) ERR_INVALID_INPUT)
        (asserts! (> expiration-date manufacture-date) ERR_INVALID_INPUT)
        (map-set pesticide-batches
            { batch-id: batch-id }
            {
                owner: tx-sender,
                pesticide-name: pesticide-name,
                manufacturer: manufacturer,
                lot-number: lot-number,
                manufacture-date: manufacture-date,
                expiration-date: expiration-date,
                initial-quantity-liters: quantity-liters,
                remaining-quantity-liters: quantity-liters,
                purchase-date: stacks-block-height,
                supplier: supplier,
                recalled: false
            }
        )
        (var-set next-batch-id (+ batch-id u1))
        (ok batch-id)
    )
)

(define-public (link-batch-to-application (batch-id uint) (application-id uint) (quantity-used uint) (farm-id uint))
    (let
        (
            (batch-data (unwrap! (map-get? pesticide-batches { batch-id: batch-id }) ERR_NOT_FOUND))
            (current-apps (default-to (list) (get application-ids (map-get? batch-applications { batch-id: batch-id }))))
            (current-batches (default-to (list) (get batch-ids (map-get? farm-batches { farm-id: farm-id }))))
        )
        (asserts! (is-eq tx-sender (get owner batch-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get recalled batch-data)) ERR_BATCH_RECALLED)
        (asserts! (<= quantity-used (get remaining-quantity-liters batch-data)) ERR_INSUFFICIENT_QUANTITY)
        (asserts! (> (get expiration-date batch-data) stacks-block-height) ERR_EXPIRED)
        (map-set pesticide-batches
            { batch-id: batch-id }
            (merge batch-data { remaining-quantity-liters: (- (get remaining-quantity-liters batch-data) quantity-used) })
        )
        (map-set batch-applications
            { batch-id: batch-id }
            { application-ids: (unwrap! (as-max-len? (append current-apps application-id) u100) ERR_INVALID_INPUT) }
        )
        (map-set application-batches
            { application-id: application-id }
            { batch-id: batch-id, quantity-used: quantity-used }
        )
        (if (is-none (index-of? current-batches batch-id))
            (map-set farm-batches
                { farm-id: farm-id }
                { batch-ids: (unwrap! (as-max-len? (append current-batches batch-id) u100) ERR_INVALID_INPUT) }
            )
            true
        )
        (ok true)
    )
)

(define-public (recall-batch (batch-id uint))
    (let
        (
            (batch-data (unwrap! (map-get? pesticide-batches { batch-id: batch-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set pesticide-batches
            { batch-id: batch-id }
            (merge batch-data { recalled: true })
        )
        (ok true)
    )
)

(define-read-only (get-batch (batch-id uint))
    (map-get? pesticide-batches { batch-id: batch-id })
)

(define-read-only (get-batch-applications (batch-id uint))
    (map-get? batch-applications { batch-id: batch-id })
)

(define-read-only (get-application-batch (application-id uint))
    (map-get? application-batches { application-id: application-id })
)

(define-read-only (get-farm-batches (farm-id uint))
    (map-get? farm-batches { farm-id: farm-id })
)

(define-read-only (check-batch-expiration (batch-id uint))
    (let
        (
            (batch-data (map-get? pesticide-batches { batch-id: batch-id }))
        )
        (if (is-some batch-data)
            (ok (> (get expiration-date (unwrap-panic batch-data)) stacks-block-height))
            ERR_NOT_FOUND
        )
    )
)
