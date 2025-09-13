(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_INPUT (err u202))
(define-constant ERR_ALREADY_EXISTS (err u203))
(define-constant ERR_RESIDUE_EXCEEDED (err u204))
(define-constant ERR_INSUFFICIENT_INTERVAL (err u205))

(define-data-var next-test-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map residue-tests
    { test-id: uint }
    {
        harvest-id: uint,
        laboratory: principal,
        pesticide-name: (string-ascii 100),
        residue-level-ppb: uint,
        test-date: uint,
        sample-size-kg: uint,
        test-method: (string-ascii 50),
        certified: bool,
        compliance-status: (string-ascii 20)
    }
)

(define-map harvest-residue-tests
    { harvest-id: uint }
    { test-ids: (list 50 uint) }
)

(define-map maximum-residue-limits
    { pesticide-name: (string-ascii 100), crop-type: (string-ascii 50) }
    { mrl-ppb: uint, detection-limit: uint }
)

(define-map certified-laboratories
    { laboratory: principal }
    {
        name: (string-ascii 100),
        certification-number: (string-ascii 50),
        active: bool,
        authorized-by: principal
    }
)

(define-public (authorize-laboratory (laboratory principal) (name (string-ascii 100)) (cert-number (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (map-set certified-laboratories
            { laboratory: laboratory }
            { name: name, certification-number: cert-number, active: true, authorized-by: tx-sender }
        )
        (ok true)
    )
)

(define-public (set-mrl (pesticide-name (string-ascii 100)) (crop-type (string-ascii 50)) (mrl-ppb uint) (detection-limit uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> mrl-ppb u0) ERR_INVALID_INPUT)
        (map-set maximum-residue-limits
            { pesticide-name: pesticide-name, crop-type: crop-type }
            { mrl-ppb: mrl-ppb, detection-limit: detection-limit }
        )
        (ok true)
    )
)

(define-public (record-residue-test (harvest-id uint) (pesticide-name (string-ascii 100)) (residue-level-ppb uint) (sample-size-kg uint) (test-method (string-ascii 50)))
    (let
        (
            (test-id (var-get next-test-id))
            (lab-data (unwrap! (map-get? certified-laboratories { laboratory: tx-sender }) ERR_UNAUTHORIZED))
            (current-tests (default-to (list) (get test-ids (map-get? harvest-residue-tests { harvest-id: harvest-id }))))
        )
        (asserts! (get active lab-data) ERR_UNAUTHORIZED)
        (asserts! (> sample-size-kg u0) ERR_INVALID_INPUT)
        (map-set residue-tests
            { test-id: test-id }
            {
                harvest-id: harvest-id,
                laboratory: tx-sender,
                pesticide-name: pesticide-name,
                residue-level-ppb: residue-level-ppb,
                test-date: stacks-block-height,
                sample-size-kg: sample-size-kg,
                test-method: test-method,
                certified: true,
                compliance-status: "pending"
            }
        )
        (map-set harvest-residue-tests
            { harvest-id: harvest-id }
            { test-ids: (unwrap! (as-max-len? (append current-tests test-id) u50) ERR_INVALID_INPUT) }
        )
        (var-set next-test-id (+ test-id u1))
        (ok test-id)
    )
)

(define-public (validate-compliance (test-id uint) (crop-type (string-ascii 50)))
    (let
        (
            (test-data (unwrap! (map-get? residue-tests { test-id: test-id }) ERR_NOT_FOUND))
            (mrl-data (map-get? maximum-residue-limits { pesticide-name: (get pesticide-name test-data), crop-type: crop-type }))
            (compliance-status (if (is-some mrl-data)
                (if (<= (get residue-level-ppb test-data) (get mrl-ppb (unwrap-panic mrl-data))) "compliant" "non-compliant")
                "no-limit-set"))
        )
        (map-set residue-tests
            { test-id: test-id }
            (merge test-data { compliance-status: compliance-status })
        )
        (ok compliance-status)
    )
)

(define-read-only (get-residue-test (test-id uint))
    (map-get? residue-tests { test-id: test-id })
)

(define-read-only (get-harvest-tests (harvest-id uint))
    (map-get? harvest-residue-tests { harvest-id: harvest-id })
)

(define-read-only (check-harvest-compliance (harvest-id uint))
    (let
        (
            (tests (default-to (list) (get test-ids (map-get? harvest-residue-tests { harvest-id: harvest-id }))))
        )
        (fold check-test-compliance tests true)
    )
)

(define-private (check-test-compliance (test-id uint) (compliant bool))
    (if compliant
        (let
            (
                (test-data (map-get? residue-tests { test-id: test-id }))
            )
            (if (is-some test-data)
                (is-eq (get compliance-status (unwrap-panic test-data)) "compliant")
                compliant
            )
        )
        false
    )
)

(define-read-only (get-mrl (pesticide-name (string-ascii 100)) (crop-type (string-ascii 50)))
    (map-get? maximum-residue-limits { pesticide-name: pesticide-name, crop-type: crop-type })
)