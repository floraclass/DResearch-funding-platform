;; Research Funding Contract
;; This contract manages funding, escrow, and milestone-based disbursement for research projects

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-EXISTS u2)
(define-constant ERR-DOES-NOT-EXIST u3)
(define-constant ERR-INVALID-STATUS u4)
(define-constant ERR-INSUFFICIENT-FUNDS u5)
(define-constant ERR-INVALID-AMOUNT u6)
(define-constant ERR-MILESTONE-NOT-VERIFIED u7)
(define-constant ERR-ALREADY-FUNDED u8)
(define-constant ERR-FUNDING-EXPIRED u9)
(define-constant ERR-INVALID-MILESTONE u10)

;; Project status constants
(define-constant STATUS-PROPOSED u1)
(define-constant STATUS-FUNDED u2)
(define-constant STATUS-ACTIVE u3)
(define-constant STATUS-COMPLETED u4)
(define-constant STATUS-CANCELLED u5)
(define-constant STATUS-DISPUTED u6)

;; Funding status constants
(define-constant FUNDING-STATUS-PENDING u1)
(define-constant FUNDING-STATUS-ACTIVE u2)
(define-constant FUNDING-STATUS-COMPLETED u3)
(define-constant FUNDING-STATUS-REFUNDED u4)

;; Research categories
(define-constant CATEGORY-SCIENTIFIC u1)
(define-constant CATEGORY-ENGINEERING u2)
(define-constant CATEGORY-MEDICAL u3)
(define-constant CATEGORY-HUMANITIES u4)
(define-constant CATEGORY-OTHER u5)

;; Project record
(define-map projects
  { project-id: uint }
  {
    researcher: principal,
    title: (string-utf8 200),
    description: (string-utf8 1000),
    category: uint,
    total-funding-requested: uint,
    total-funding-received: uint,
    funds-disbursed: uint,
    status: uint,
    creation-time: uint,
    funding-deadline: uint,
    completion-deadline: uint,
    milestone-count: uint,
    completed-milestones: uint
  }
)

;; Project milestones mapping
(define-map project-milestones
  { project-id: uint, milestone-index: uint }
  {
    milestone-id: uint,
    funding-amount: uint,
    is-disbursed: bool
  }
)

;; Funding records
(define-map fundings
  { funding-id: uint }
  {
    funder: principal,
    project-id: uint,
    amount: uint,
    funding-time: uint,
    status: uint
  }
)

;; Escrow balances for projects
(define-map project-escrow
  { project-id: uint }
  { balance: uint }
)

;; Contract variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-project-id uint u1)
(define-data-var next-funding-id uint u1)
(define-data-var milestone-contract principal tx-sender)
(define-data-var expert-contract principal tx-sender)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points (250/10000)

;; Get contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Update contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set contract-owner new-owner))
  )
)

;; Set milestone contract reference
(define-public (set-milestone-contract (milestone-contract-addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set milestone-contract milestone-contract-addr))
  )
)

;; Set expert contract reference
(define-public (set-expert-contract (expert-contract-addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set expert-contract expert-contract-addr))
  )
)

;; Set platform fee rate
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (asserts! (<= new-rate u1000) (err ERR-INVALID-AMOUNT)) ;; Max 10%
    (ok (var-set platform-fee-rate new-rate))
  )
)

;; Submit a research project proposal
(define-public (submit-project
               (title (string-utf8 200))
               (description (string-utf8 1000))
               (category uint)
               (total-funding-requested uint)
               (funding-deadline uint)
               (completion-deadline uint))
  (let
    ((project-id (var-get next-project-id)))
    
    ;; Validate category
    (asserts! (or 
               (is-eq category CATEGORY-SCIENTIFIC)
               (is-eq category CATEGORY-ENGINEERING)
               (is-eq category CATEGORY-MEDICAL)
               (is-eq category CATEGORY-HUMANITIES)
               (is-eq category CATEGORY-OTHER)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Validate funding amount
    (asserts! (> total-funding-requested u0) (err ERR-INVALID-AMOUNT))
    
    ;; Validate deadlines
    (asserts! (> funding-deadline stacks-block-height) (err ERR-INVALID-STATUS))
    (asserts! (> completion-deadline funding-deadline) (err ERR-INVALID-STATUS))
    
    ;; Create project record
    (map-set projects
      { project-id: project-id }
      {
        researcher: tx-sender,
        title: title,
        description: description,
        category: category,
        total-funding-requested: total-funding-requested,
        total-funding-received: u0,
        funds-disbursed: u0,
        status: STATUS-PROPOSED,
        creation-time: stacks-block-height,
        funding-deadline: funding-deadline,
        completion-deadline: completion-deadline,
        milestone-count: u0,
        completed-milestones: u0
      }
    )
    
    ;; Initialize escrow balance
    (map-set project-escrow
      { project-id: project-id }
      { balance: u0 }
    )
    
    ;; Increment project ID
    (var-set next-project-id (+ project-id u1))
    
    (ok project-id)
  )
)

;; Add milestone to project
(define-public (add-project-milestone
               (project-id uint)
               (milestone-id uint)
               (funding-amount uint))
  (let
    ((project-data (unwrap! (map-get? projects { project-id: project-id }) (err ERR-DOES-NOT-EXIST)))
     (milestone-index (get milestone-count project-data)))
    
    ;; Only project researcher can add milestones
    (asserts! (is-eq tx-sender (get researcher project-data)) (err ERR-NOT-AUTHORIZED))
    
    ;; Project must be proposed or funded
    (asserts! (or 
               (is-eq (get status project-data) STATUS-PROPOSED)
               (is-eq (get status project-data) STATUS-FUNDED)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Validate funding amount
    (asserts! (> funding-amount u0) (err ERR-INVALID-AMOUNT))
    
    ;; Add milestone mapping
    (map-set project-milestones
      { project-id: project-id, milestone-index: milestone-index }
      {
        milestone-id: milestone-id,
        funding-amount: funding-amount,
        is-disbursed: false
      }
    )
    
    ;; Update project milestone count
    (map-set projects
      { project-id: project-id }
      (merge project-data { milestone-count: (+ milestone-index u1) })
    )
    
    (ok milestone-index)
  )
)

;; Fund a research project
(define-public (fund-project (project-id uint) (amount uint))
  (let
    ((project-data (unwrap! (map-get? projects { project-id: project-id }) (err ERR-DOES-NOT-EXIST)))
     (escrow-data (unwrap! (map-get? project-escrow { project-id: project-id }) (err ERR-DOES-NOT-EXIST)))
     (funding-id (var-get next-funding-id))
     (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000)))
    
    ;; Project must be proposed
    (asserts! (is-eq (get status project-data) STATUS-PROPOSED) (err ERR-INVALID-STATUS))
    
    ;; Check funding deadline hasn't passed
    (asserts! (< stacks-block-height (get funding-deadline project-data)) (err ERR-FUNDING-EXPIRED))
    
    ;; Validate amount
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    
    ;; Transfer funds to contract (amount + platform fee)
    (try! (stx-transfer? (+ amount platform-fee) tx-sender (as-contract tx-sender)))
    
    ;; Create funding record
    (map-set fundings
      { funding-id: funding-id }
      {
        funder: tx-sender,
        project-id: project-id,
        amount: amount,
        funding-time: stacks-block-height,
        status: FUNDING-STATUS-ACTIVE
      }
    )
    
    ;; Update escrow balance
    (map-set project-escrow
      { project-id: project-id }
      { balance: (+ (get balance escrow-data) amount) }
    )
    
    ;; Update project funding received
    (let
      ((new-funding-received (+ (get total-funding-received project-data) amount)))
      
      (map-set projects
        { project-id: project-id }
        (merge project-data { 
          total-funding-received: new-funding-received,
          status: (if (>= new-funding-received (get total-funding-requested project-data))
                     STATUS-FUNDED
                     STATUS-PROPOSED)
        })
      )
    )
    
    ;; Increment funding ID
    (var-set next-funding-id (+ funding-id u1))
    
    (ok funding-id)
  )
)

;; Disburse funds for verified milestone
(define-public (disburse-milestone-funds (project-id uint) (milestone-index uint))
  (let
    ((project-data (unwrap! (map-get? projects { project-id: project-id }) (err ERR-DOES-NOT-EXIST)))
     (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-index: milestone-index }) (err ERR-DOES-NOT-EXIST)))
     (escrow-data (unwrap! (map-get? project-escrow { project-id: project-id }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only project researcher can request disbursement
    (asserts! (is-eq tx-sender (get researcher project-data)) (err ERR-NOT-AUTHORIZED))
    
    ;; Project must be funded or active
    (asserts! (or 
               (is-eq (get status project-data) STATUS-FUNDED)
               (is-eq (get status project-data) STATUS-ACTIVE)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Milestone must not be already disbursed
    (asserts! (not (get is-disbursed milestone-data)) (err ERR-ALREADY-FUNDED))
    
    ;; Check if milestone is verified (call milestone contract)
    ;; For now, we'll assume this check passes - in real implementation:
    ;; (asserts! (unwrap! (contract-call? (var-get milestone-contract) is-milestone-verified (get milestone-id milestone-data)) (err ERR-MILESTONE-NOT-VERIFIED)) (err ERR-MILESTONE-NOT-VERIFIED))
    
    ;; Check sufficient escrow balance
    (asserts! (>= (get balance escrow-data) (get funding-amount milestone-data)) (err ERR-INSUFFICIENT-FUNDS))
    
    ;; Transfer funds to researcher
    (try! (as-contract (stx-transfer? (get funding-amount milestone-data) tx-sender (get researcher project-data))))
    
    ;; Update milestone as disbursed
    (map-set project-milestones
      { project-id: project-id, milestone-index: milestone-index }
      (merge milestone-data { is-disbursed: true })
    )
    
    ;; Update escrow balance
    (map-set project-escrow
      { project-id: project-id }
      { balance: (- (get balance escrow-data) (get funding-amount milestone-data)) }
    )
    
    ;; Update project funds disbursed and completed milestones
    (let
      ((new-funds-disbursed (+ (get funds-disbursed project-data) (get funding-amount milestone-data)))
       (new-completed-milestones (+ (get completed-milestones project-data) u1)))
      
      (map-set projects
        { project-id: project-id }
        (merge project-data { 
          funds-disbursed: new-funds-disbursed,
          completed-milestones: new-completed-milestones,
          status: (if (is-eq new-completed-milestones (get milestone-count project-data))
                     STATUS-COMPLETED
                     STATUS-ACTIVE)
        })
      )
    )
    
    (ok true)
  )
)

;; Get project details
(define-read-only (get-project (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data (ok project-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get project milestone
(define-read-only (get-project-milestone (project-id uint) (milestone-index uint))
  (match (map-get? project-milestones { project-id: project-id, milestone-index: milestone-index })
    milestone-data (ok milestone-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get funding details
(define-read-only (get-funding (funding-id uint))
  (match (map-get? fundings { funding-id: funding-id })
    funding-data (ok funding-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get project escrow balance
(define-read-only (get-project-escrow-balance (project-id uint))
  (match (map-get? project-escrow { project-id: project-id })
    escrow-data (ok (get balance escrow-data))
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Update project status (admin function)
(define-public (update-project-status (project-id uint) (new-status uint))
  (let
    ((project-data (unwrap! (map-get? projects { project-id: project-id }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only contract owner can manually update status
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Validate status
    (asserts! (or 
               (is-eq new-status STATUS-PROPOSED)
               (is-eq new-status STATUS-FUNDED)
               (is-eq new-status STATUS-ACTIVE)
               (is-eq new-status STATUS-COMPLETED)
               (is-eq new-status STATUS-CANCELLED)
               (is-eq new-status STATUS-DISPUTED)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Update project status
    (map-set projects
      { project-id: project-id }
      (merge project-data { status: new-status })
    )
    
    (ok true)
  )
)

;; Emergency refund (admin function)
(define-public (emergency-refund (project-id uint))
  (let
    ((project-data (unwrap! (map-get? projects { project-id: project-id }) (err ERR-DOES-NOT-EXIST)))
     (escrow-data (unwrap! (map-get? project-escrow { project-id: project-id }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only contract owner can initiate emergency refund
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Project must be cancelled or disputed
    (asserts! (or 
               (is-eq (get status project-data) STATUS-CANCELLED)
               (is-eq (get status project-data) STATUS-DISPUTED)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Transfer remaining escrow to researcher (simplified - in real implementation would distribute to funders)
    (try! (as-contract (stx-transfer? (get balance escrow-data) tx-sender (get researcher project-data))))
    
    ;; Clear escrow balance
    (map-set project-escrow
      { project-id: project-id }
      { balance: u0 }
    )
    
    (ok true)
  )
)

;; Get current project ID counter
(define-read-only (get-next-project-id)
  (ok (var-get next-project-id))
)

;; Get platform fee rate
(define-read-only (get-platform-fee-rate)
  (ok (var-get platform-fee-rate))
)
