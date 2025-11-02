(define-constant ERR_NOT_FOUND (err u700))
(define-constant ERR_NOT_MEMBER (err u701))
(define-constant ERR_INSUFFICIENT_FUNDS (err u702))
(define-constant ERR_ALREADY_USED (err u703))
(define-constant ERR_INVALID_AMOUNT (err u704))
(define-constant ERR_COOLDOWN_ACTIVE (err u705))

(define-constant EMERGENCY_FEE_PERCENTAGE u5)
(define-constant EMERGENCY_ADVANCE_LIMIT u2)
(define-constant COOLDOWN_BLOCKS u2016)

(define-map rosca-emergency-pools uint {
    total-balance: uint,
    total-members: uint,
    total-advances-issued: uint,
    is-active: bool
})

(define-map member-pool-participation {rosca-id: uint, member: principal} {
    total-contributed: uint,
    advances-used: uint,
    last-advance-block: uint,
    is-enrolled: bool
})

(define-map emergency-advance-requests {rosca-id: uint, member: principal, request-id: uint} {
    amount: uint,
    requested-at: uint,
    repaid-amount: uint,
    is-repaid: bool
})

(define-data-var total-advance-requests uint u0)

(define-read-only (get-pool-balance (rosca-id uint))
    (default-to {
        total-balance: u0,
        total-members: u0,
        total-advances-issued: u0,
        is-active: false
    } (map-get? rosca-emergency-pools rosca-id))
)

(define-read-only (get-member-participation (rosca-id uint) (member principal))
    (map-get? member-pool-participation {rosca-id: rosca-id, member: member})
)

(define-public (enroll-in-emergency-pool (rosca-id uint) (initial-deposit uint))
    (let (
        (pool-data (get-pool-balance rosca-id))
        (existing-enrollment (get-member-participation rosca-id tx-sender))
    )
        (asserts! (is-none existing-enrollment) ERR_ALREADY_USED)
        (asserts! (> initial-deposit u0) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? initial-deposit tx-sender (as-contract tx-sender)))
        
        (map-set member-pool-participation {rosca-id: rosca-id, member: tx-sender} {
            total-contributed: initial-deposit,
            advances-used: u0,
            last-advance-block: u0,
            is-enrolled: true
        })
        
        (map-set rosca-emergency-pools rosca-id {
            total-balance: (+ (get total-balance pool-data) initial-deposit),
            total-members: (+ (get total-members pool-data) u1),
            total-advances-issued: (get total-advances-issued pool-data),
            is-active: true
        })
        (ok true)
    )
)

(define-public (request-emergency-advance (rosca-id uint) (amount uint))
    (let (
        (pool-data (get-pool-balance rosca-id))
        (member-data (unwrap! (get-member-participation rosca-id tx-sender) ERR_NOT_MEMBER))
        (request-id (+ (var-get total-advance-requests) u1))
        (blocks-since-last (- stacks-block-height (get last-advance-block member-data)))
    )
        (asserts! (get is-enrolled member-data) ERR_NOT_MEMBER)
        (asserts! (< (get advances-used member-data) EMERGENCY_ADVANCE_LIMIT) ERR_ALREADY_USED)
        (asserts! (>= blocks-since-last COOLDOWN_BLOCKS) ERR_COOLDOWN_ACTIVE)
        (asserts! (<= amount (get total-balance pool-data)) ERR_INSUFFICIENT_FUNDS)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        (map-set emergency-advance-requests {rosca-id: rosca-id, member: tx-sender, request-id: request-id} {
            amount: amount,
            requested-at: stacks-block-height,
            repaid-amount: u0,
            is-repaid: false
        })
        
        (map-set member-pool-participation {rosca-id: rosca-id, member: tx-sender} (merge member-data {
            advances-used: (+ (get advances-used member-data) u1),
            last-advance-block: stacks-block-height
        }))
        
        (map-set rosca-emergency-pools rosca-id (merge pool-data {
            total-balance: (- (get total-balance pool-data) amount),
            total-advances-issued: (+ (get total-advances-issued pool-data) u1)
        }))
        
        (var-set total-advance-requests request-id)
        (ok request-id)
    )
)

(define-public (repay-emergency-advance (rosca-id uint) (request-id uint) (repay-amount uint))
    (let (
        (pool-data (get-pool-balance rosca-id))
        (advance-data (unwrap! (map-get? emergency-advance-requests {rosca-id: rosca-id, member: tx-sender, request-id: request-id}) ERR_NOT_FOUND))
        (outstanding (- (get amount advance-data) (get repaid-amount advance-data)))
    )
        (asserts! (not (get is-repaid advance-data)) ERR_ALREADY_USED)
        (asserts! (<= repay-amount outstanding) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
        
        (let ((new-repaid (+ (get repaid-amount advance-data) repay-amount)))
            (map-set emergency-advance-requests {rosca-id: rosca-id, member: tx-sender, request-id: request-id} (merge advance-data {
                repaid-amount: new-repaid,
                is-repaid: (is-eq new-repaid (get amount advance-data))
            }))
        )
        
        (map-set rosca-emergency-pools rosca-id (merge pool-data {
            total-balance: (+ (get total-balance pool-data) repay-amount)
        }))
        (ok true)
    )
)
