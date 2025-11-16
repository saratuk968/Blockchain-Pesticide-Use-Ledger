(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_INVALID_INPUT (err u502))
(define-constant ERR_EXPIRED (err u503))
(define-constant ERR_RECALLED (err u504))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u505))
(define-constant ERR_PENDING_TRANSFER (err u506))
(define-constant ERR_INVALID_STATUS (err u507))

(define-data-var next-transfer-id uint u1)

(define-map transfer-requests
    { transfer-id: uint }
    {
        batch-id: uint,
        from-owner: principal,
        to-recipient: principal,
        quantity-liters: uint,
        transfer-price: uint,
        request-date: uint,
        status: (string-ascii 20),
        completed-date: (optional uint)
    }
)

(define-map batch-transfer-history
    { batch-id: uint }
    { transfer-ids: (list 50 uint) }
)

(define-map pending-transfers-by-recipient
    { recipient: principal }
    { transfer-ids: (list 50 uint) }
)

(define-public (initiate-transfer (batch-id uint) (recipient principal) (quantity-liters uint) (transfer-price uint))
    (let
        (
            (transfer-id (var-get next-transfer-id))
            (batch-history (default-to (list) (get transfer-ids (map-get? batch-transfer-history { batch-id: batch-id }))))
            (recipient-pending (default-to (list) (get transfer-ids (map-get? pending-transfers-by-recipient { recipient: recipient }))))
        )
        (asserts! (not (is-eq tx-sender recipient)) ERR_INVALID_INPUT)
        (asserts! (> quantity-liters u0) ERR_INVALID_INPUT)
        (map-set transfer-requests
            { transfer-id: transfer-id }
            {
                batch-id: batch-id,
                from-owner: tx-sender,
                to-recipient: recipient,
                quantity-liters: quantity-liters,
                transfer-price: transfer-price,
                request-date: stacks-block-height,
                status: "pending",
                completed-date: none
            }
        )
        (map-set batch-transfer-history
            { batch-id: batch-id }
            { transfer-ids: (unwrap! (as-max-len? (append batch-history transfer-id) u50) ERR_INVALID_INPUT) }
        )
        (map-set pending-transfers-by-recipient
            { recipient: recipient }
            { transfer-ids: (unwrap! (as-max-len? (append recipient-pending transfer-id) u50) ERR_INVALID_INPUT) }
        )
        (var-set next-transfer-id (+ transfer-id u1))
        (ok transfer-id)
    )
)

(define-public (accept-transfer (transfer-id uint))
    (let
        (
            (transfer-data (unwrap! (map-get? transfer-requests { transfer-id: transfer-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get to-recipient transfer-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-data) "pending") ERR_INVALID_STATUS)
        (map-set transfer-requests
            { transfer-id: transfer-id }
            (merge transfer-data { status: "accepted", completed-date: (some stacks-block-height) })
        )
        (ok true)
    )
)

(define-public (reject-transfer (transfer-id uint))
    (let
        (
            (transfer-data (unwrap! (map-get? transfer-requests { transfer-id: transfer-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get to-recipient transfer-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-data) "pending") ERR_INVALID_STATUS)
        (map-set transfer-requests
            { transfer-id: transfer-id }
            (merge transfer-data { status: "rejected", completed-date: (some stacks-block-height) })
        )
        (ok true)
    )
)

(define-public (cancel-transfer (transfer-id uint))
    (let
        (
            (transfer-data (unwrap! (map-get? transfer-requests { transfer-id: transfer-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get from-owner transfer-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-data) "pending") ERR_INVALID_STATUS)
        (map-set transfer-requests
            { transfer-id: transfer-id }
            (merge transfer-data { status: "cancelled", completed-date: (some stacks-block-height) })
        )
        (ok true)
    )
)

(define-read-only (get-transfer (transfer-id uint))
    (map-get? transfer-requests { transfer-id: transfer-id })
)

(define-read-only (get-batch-transfers (batch-id uint))
    (map-get? batch-transfer-history { batch-id: batch-id })
)

(define-read-only (get-pending-transfers (recipient principal))
    (map-get? pending-transfers-by-recipient { recipient: recipient })
)

(define-read-only (get-transfer-count (batch-id uint))
    (let
        (
            (transfers (get transfer-ids (map-get? batch-transfer-history { batch-id: batch-id })))
        )
        (if (is-some transfers)
            (len (unwrap-panic transfers))
            u0
        )
    )
)
