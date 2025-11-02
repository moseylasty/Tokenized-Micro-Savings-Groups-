(define-constant ERR_NOT_FOUND (err u600))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u601))
(define-constant ERR_ALREADY_REQUESTED (err u602))
(define-constant ERR_NO_ACTIVE_REQUEST (err u603))
(define-constant ERR_INVALID_AMOUNT (err u604))
(define-constant ERR_NOT_AUTHORIZED (err u605))

(define-constant MIN_REPUTATION_SCORE u500)
(define-constant REPUTATION_COST_PER_CYCLE u100)
(define-constant MAX_EARLY_ACCESS_SLOTS u3)

(define-data-var total-early-access-requests uint u0)

(define-map early-access-requests {rosca-id: uint, member: principal} {
    reputation-staked: uint,
    cycles-to-advance: uint,
    requested-at: uint,
    is-active: bool,
    priority-score: uint
})

(define-map rosca-early-access-queue {rosca-id: uint, position: uint} principal)

(define-map member-reputation principal {
    score: uint,
    total-staked: uint,
    successful-claims: uint,
    failed-claims: uint
})

(define-read-only (get-member-reputation (member principal))
    (default-to {
        score: u100,
        total-staked: u0,
        successful-claims: u0,
        failed-claims: u0
    } (map-get? member-reputation member))
)

(define-read-only (get-early-access-request (rosca-id uint) (member principal))
    (map-get? early-access-requests {rosca-id: rosca-id, member: member})
)

(define-read-only (calculate-priority-score (reputation uint) (cycles uint))
    (* reputation cycles)
)

(define-public (request-early-access (rosca-id uint) (cycles-to-advance uint))
    (let (
        (member-rep (get-member-reputation tx-sender))
        (reputation-score (get score member-rep))
        (reputation-cost (* REPUTATION_COST_PER_CYCLE cycles-to-advance))
        (existing-request (get-early-access-request rosca-id tx-sender))
        (priority (calculate-priority-score reputation-score cycles-to-advance))
    )
        (asserts! (is-none existing-request) ERR_ALREADY_REQUESTED)
        (asserts! (>= reputation-score MIN_REPUTATION_SCORE) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (>= reputation-score reputation-cost) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (and (> cycles-to-advance u0) (<= cycles-to-advance u5)) ERR_INVALID_AMOUNT)
        
        (map-set early-access-requests {rosca-id: rosca-id, member: tx-sender} {
            reputation-staked: reputation-cost,
            cycles-to-advance: cycles-to-advance,
            requested-at: stacks-block-height,
            is-active: true,
            priority-score: priority
        })
        
        (map-set member-reputation tx-sender (merge member-rep {
            total-staked: (+ (get total-staked member-rep) reputation-cost),
            score: (- reputation-score reputation-cost)
        }))
        
        (var-set total-early-access-requests (+ (var-get total-early-access-requests) u1))
        (ok priority)
    )
)

(define-public (claim-early-access-slot (rosca-id uint))
    (let (
        (request (unwrap! (get-early-access-request rosca-id tx-sender) ERR_NO_ACTIVE_REQUEST))
        (member-rep (get-member-reputation tx-sender))
    )
        (asserts! (get is-active request) ERR_NO_ACTIVE_REQUEST)
        
        (map-set early-access-requests {rosca-id: rosca-id, member: tx-sender} (merge request {
            is-active: false
        }))
        
        (map-set member-reputation tx-sender (merge member-rep {
            successful-claims: (+ (get successful-claims member-rep) u1)
        }))
        
        (ok (get cycles-to-advance request))
    )
)

(define-public (cancel-early-access-request (rosca-id uint))
    (let (
        (request (unwrap! (get-early-access-request rosca-id tx-sender) ERR_NO_ACTIVE_REQUEST))
        (member-rep (get-member-reputation tx-sender))
        (refund-amount (/ (* (get reputation-staked request) u75) u100))
    )
        (asserts! (get is-active request) ERR_NO_ACTIVE_REQUEST)
        
        (map-set early-access-requests {rosca-id: rosca-id, member: tx-sender} (merge request {
            is-active: false
        }))
        
        (map-set member-reputation tx-sender (merge member-rep {
            score: (+ (get score member-rep) refund-amount),
            total-staked: (- (get total-staked member-rep) (get reputation-staked request))
        }))
        
        (ok refund-amount)
    )
)

(define-read-only (get-early-access-eligibility (member principal) (cycles uint))
    (let (
        (member-rep (get-member-reputation member))
        (required-rep (* REPUTATION_COST_PER_CYCLE cycles))
    )
        (ok {
            is-eligible: (and (>= (get score member-rep) MIN_REPUTATION_SCORE) (>= (get score member-rep) required-rep)),
            current-reputation: (get score member-rep),
            required-reputation: required-rep,
            reputation-shortfall: (if (< (get score member-rep) required-rep) (- required-rep (get score member-rep)) u0)
        })
    )
)
