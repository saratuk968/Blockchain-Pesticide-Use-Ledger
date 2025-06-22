(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_INPUT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_STATUS (err u104))

(define-data-var next-farm-id uint u1)
(define-data-var next-application-id uint u1)

(define-map farms
    { farm-id: uint }
    {
        owner: principal,
        name: (string-ascii 100),
        location: (string-ascii 200),
        size-hectares: uint,
        organic-certified: bool,
        certification-date: uint,
        status: (string-ascii 20)
    }
)

(define-map farm-owners
    { owner: principal }
    { farm-ids: (list 50 uint) }
)

(define-map pesticide-applications
    { application-id: uint }
    {
        farm-id: uint,
        applicator: principal,
        pesticide-name: (string-ascii 100),
        pesticide-type: (string-ascii 50),
        active-ingredient: (string-ascii 100),
        concentration: uint,
        quantity-liters: uint,
        application-date: uint,
        crop-type: (string-ascii 50),
        area-treated: uint,
        weather-conditions: (string-ascii 100),
        pre-harvest-interval: uint,
        organic-approved: bool,
        verified: bool,
        verifier: (optional principal)
    }
)

(define-map farm-applications
    { farm-id: uint }
    { application-ids: (list 200 uint) }
)

(define-map approved-pesticides
    { pesticide-name: (string-ascii 100) }
    {
        active-ingredient: (string-ascii 100),
        organic-approved: bool,
        max-concentration: uint,
        pre-harvest-days: uint,
        restricted-crops: (list 20 (string-ascii 50))
    }
)

(define-map inspectors
    { inspector: principal }
    {
        name: (string-ascii 100),
        certification-number: (string-ascii 50),
        active: bool,
        authorized-by: principal
    }
)

(define-public (register-farm (name (string-ascii 100)) (location (string-ascii 200)) (size-hectares uint) (organic-certified bool))
    (let
        (
            (farm-id (var-get next-farm-id))
            (current-farms (default-to (list) (get farm-ids (map-get? farm-owners { owner: tx-sender }))))
        )
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (asserts! (> size-hectares u0) ERR_INVALID_INPUT)
        (map-set farms
            { farm-id: farm-id }
            {
                owner: tx-sender,
                name: name,
                location: location,
                size-hectares: size-hectares,
                organic-certified: organic-certified,
                certification-date: (if organic-certified stacks-block-height u0),
                status: "active"
            }
        )
        (map-set farm-owners
            { owner: tx-sender }
            { farm-ids: (unwrap! (as-max-len? (append current-farms farm-id) u50) ERR_INVALID_INPUT) }
        )
        (var-set next-farm-id (+ farm-id u1))
        (ok farm-id)
    )
)

(define-public (add-approved-pesticide (pesticide-name (string-ascii 100)) (active-ingredient (string-ascii 100)) (organic-approved bool) (max-concentration uint) (pre-harvest-days uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> (len pesticide-name) u0) ERR_INVALID_INPUT)
        (asserts! (is-none (map-get? approved-pesticides { pesticide-name: pesticide-name })) ERR_ALREADY_EXISTS)
        (map-set approved-pesticides
            { pesticide-name: pesticide-name }
            {
                active-ingredient: active-ingredient,
                organic-approved: organic-approved,
                max-concentration: max-concentration,
                pre-harvest-days: pre-harvest-days,
                restricted-crops: (list)
            }
        )
        (ok true)
    )
)

(define-public (authorize-inspector (inspector principal) (name (string-ascii 100)) (certification-number (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (map-set inspectors
            { inspector: inspector }
            {
                name: name,
                certification-number: certification-number,
                active: true,
                authorized-by: tx-sender
            }
        )
        (ok true)
    )
)

(define-public (record-pesticide-application 
    (farm-id uint) 
    (pesticide-name (string-ascii 100)) 
    (pesticide-type (string-ascii 50))
    (concentration uint) 
    (quantity-liters uint) 
    (crop-type (string-ascii 50)) 
    (area-treated uint)
    (weather-conditions (string-ascii 100))
)
    (let
        (
            (application-id (var-get next-application-id))
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_NOT_FOUND))
            (pesticide-data (map-get? approved-pesticides { pesticide-name: pesticide-name }))
            (current-applications (default-to (list) (get application-ids (map-get? farm-applications { farm-id: farm-id }))))
            (organic-approved (if (is-some pesticide-data) (get organic-approved (unwrap-panic pesticide-data)) false))
            (pre-harvest-interval (if (is-some pesticide-data) (get pre-harvest-days (unwrap-panic pesticide-data)) u30))
            (active-ingredient (if (is-some pesticide-data) (get active-ingredient (unwrap-panic pesticide-data)) "unknown"))
        )
        (asserts! (is-eq tx-sender (get owner farm-data)) ERR_UNAUTHORIZED)
        (asserts! (> quantity-liters u0) ERR_INVALID_INPUT)
        (asserts! (> area-treated u0) ERR_INVALID_INPUT)
        (asserts! (<= area-treated (get size-hectares farm-data)) ERR_INVALID_INPUT)
        (map-set pesticide-applications
            { application-id: application-id }
            {
                farm-id: farm-id,
                applicator: tx-sender,
                pesticide-name: pesticide-name,
                pesticide-type: pesticide-type,
                active-ingredient: active-ingredient,
                concentration: concentration,
                quantity-liters: quantity-liters,
                application-date: stacks-block-height,
                crop-type: crop-type,
                area-treated: area-treated,
                weather-conditions: weather-conditions,
                pre-harvest-interval: pre-harvest-interval,
                organic-approved: organic-approved,
                verified: false,
                verifier: none
            }
        )
        (map-set farm-applications
            { farm-id: farm-id }
            { application-ids: (unwrap! (as-max-len? (append current-applications application-id) u200) ERR_INVALID_INPUT) }
        )
        (var-set next-application-id (+ application-id u1))
        (ok application-id)
    )
)

(define-public (verify-application (application-id uint))
    (let
        (
            (application-data (unwrap! (map-get? pesticide-applications { application-id: application-id }) ERR_NOT_FOUND))
            (inspector-data (unwrap! (map-get? inspectors { inspector: tx-sender }) ERR_UNAUTHORIZED))
        )
        (asserts! (get active inspector-data) ERR_UNAUTHORIZED)
        (asserts! (not (get verified application-data)) ERR_INVALID_STATUS)
        (map-set pesticide-applications
            { application-id: application-id }
            (merge application-data { verified: true, verifier: (some tx-sender) })
        )
        (ok true)
    )
)

(define-public (update-organic-certification (farm-id uint) (certified bool))
    (let
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get owner farm-data)) ERR_UNAUTHORIZED)
        (map-set farms
            { farm-id: farm-id }
            (merge farm-data { 
                organic-certified: certified,
                certification-date: (if certified stacks-block-height (get certification-date farm-data))
            })
        )
        (ok true)
    )
)

(define-read-only (get-farm (farm-id uint))
    (map-get? farms { farm-id: farm-id })
)

(define-read-only (get-farm-applications (farm-id uint))
    (map-get? farm-applications { farm-id: farm-id })
)

(define-read-only (get-application (application-id uint))
    (map-get? pesticide-applications { application-id: application-id })
)

(define-read-only (get-approved-pesticide (pesticide-name (string-ascii 100)))
    (map-get? approved-pesticides { pesticide-name: pesticide-name })
)

(define-read-only (get-inspector (inspector principal))
    (map-get? inspectors { inspector: inspector })
)

(define-read-only (get-farmer-farms (farmer principal))
    (map-get? farm-owners { owner: farmer })
)

(define-read-only (check-organic-compliance (farm-id uint))
    (let
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) (err "Farm not found")))
            (applications (default-to (list) (get application-ids (map-get? farm-applications { farm-id: farm-id }))))
        )
        (if (get organic-certified farm-data)
            (ok (fold check-application-organic applications true))
            (ok true)
        )
    )
)

(define-private (check-application-organic (application-id uint) (compliant bool))
    (if compliant
        (let
            (
                (app-data (map-get? pesticide-applications { application-id: application-id }))
            )
            (if (is-some app-data)
                (get organic-approved (unwrap-panic app-data))
                compliant
            )
        )
        false
    )
)

(define-read-only (get-recent-applications (farm-id uint) (days-back uint))
    (let
        (
            (current-block stacks-block-height)
            (cutoff-block (if (> current-block (* days-back u144)) (- current-block (* days-back u144)) u0))
            (applications (default-to (list) (get application-ids (map-get? farm-applications { farm-id: farm-id }))))
        )
        (fold filter-recent-applications applications (list))
    )
)

(define-private (filter-recent-applications (application-id uint) (acc (list 200 uint)))
    (let
        (
            (app-data (map-get? pesticide-applications { application-id: application-id }))
            (current-block stacks-block-height)
            (cutoff-block (if (> current-block u4320) (- current-block u4320) u0))
        )
        (if (and (is-some app-data) (>= (get application-date (unwrap-panic app-data)) cutoff-block))
            (unwrap! (as-max-len? (append acc application-id) u200) acc)
            acc
        )
    )
)

(define-read-only (get-application-count (farm-id uint))
    (let
        (
            (applications (get application-ids (map-get? farm-applications { farm-id: farm-id })))
        )
        (if (is-some applications)
            (len (unwrap-panic applications))
            u0
        )
    )
)

(define-read-only (get-total-farms)
    (- (var-get next-farm-id) u1)
)

(define-read-only (get-total-applications)
    (- (var-get next-application-id) u1)
)

(define-read-only (is-farm-organic-compliant (farm-id uint))
    (let
        (
            (farm-data (map-get? farms { farm-id: farm-id }))
            (applications (default-to (list) (get application-ids (map-get? farm-applications { farm-id: farm-id }))))
        )
        (if (and (is-some farm-data) (get organic-certified (unwrap-panic farm-data)))
            (fold check-application-organic applications true)
            true
        )
    )
)

(define-read-only (get-farm-by-owner (owner principal))
    (map-get? farm-owners { owner: owner })
)

(define-read-only (get-unverified-applications (farm-id uint))
    (let
        (
            (applications (default-to (list) (get application-ids (map-get? farm-applications { farm-id: farm-id }))))
        )
        (fold filter-unverified-applications applications (list))
    )
)

(define-private (filter-unverified-applications (application-id uint) (acc (list 200 uint)))
    (let
        (
            (app-data (map-get? pesticide-applications { application-id: application-id }))
        )
        (if (and (is-some app-data) (not (get verified (unwrap-panic app-data))))
            (unwrap! (as-max-len? (append acc application-id) u200) acc)
            acc
        )
    )
)
