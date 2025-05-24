;; Research Milestone Contract
;; This contract manages the submission, verification, and tracking of research milestones

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-EXISTS u2)
(define-constant ERR-DOES-NOT-EXIST u3)
(define-constant ERR-INVALID-STATUS u4)
(define-constant ERR-NOT-EXPERT u5)
(define-constant ERR-ALREADY-VERIFIED u6)
(define-constant ERR-INSUFFICIENT-VERIFICATIONS u7)

;; Milestone status constants
(define-constant STATUS-SUBMITTED u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-VERIFIED u3)
(define-constant STATUS-REJECTED u4)
(define-constant STATUS-DISPUTED u5)

;; Milestone types
(define-constant TYPE-RESEARCH-PAPER u1)
(define-constant TYPE-EXPERIMENT-RESULT u2)
(define-constant TYPE-DATA-ANALYSIS u3)
(define-constant TYPE-PROTOTYPE u4)
(define-constant TYPE-LITERATURE-REVIEW u5)

;; Verification decision constants
(define-constant DECISION-APPROVE u1)
(define-constant DECISION-REJECT u2)
(define-constant DECISION-REQUEST-REVISION u3)

;; Required number of expert verifications for approval
(define-constant REQUIRED-VERIFICATIONS u3)

;; Milestone record
(define-map milestones
  { milestone-id: uint }
  {
    researcher: principal,
    title: (string-utf8 200),
    description: (string-utf8 1000),
    milestone-type: uint,
    status: uint,
    submission-time: uint,
    verification-deadline: uint,
    ipfs-hash: (string-utf8 100),
    required-field: uint,
    approval-count: uint,
    rejection-count: uint,
    total-verifications: uint
  }
)

;; Expert verification records for each milestone
(define-map milestone-verifications
  { milestone-id: uint, expert: principal }
  {
    decision: uint,
    comments: (string-utf8 500),
    verification-time: uint
  }
)

;; Contract variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-milestone-id uint u1)
(define-data-var expert-contract principal tx-sender) ;; Reference to expert verification contract

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

;; Set expert contract reference
(define-public (set-expert-contract (expert-contract-addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set expert-contract expert-contract-addr))
  )
)

;; Submit a research milestone
(define-public (submit-milestone
               (title (string-utf8 200))
               (description (string-utf8 1000))
               (milestone-type uint)
               (ipfs-hash (string-utf8 100))
               (required-field uint)
               (verification-deadline uint))
  (let
    ((milestone-id (var-get next-milestone-id)))
    
    ;; Validate milestone type
    (asserts! (or 
               (is-eq milestone-type TYPE-RESEARCH-PAPER)
               (is-eq milestone-type TYPE-EXPERIMENT-RESULT)
               (is-eq milestone-type TYPE-DATA-ANALYSIS)
               (is-eq milestone-type TYPE-PROTOTYPE)
               (is-eq milestone-type TYPE-LITERATURE-REVIEW)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Validate deadline is in the future
    (asserts! (> verification-deadline stacks-block-height) (err ERR-INVALID-STATUS))
    
    ;; Create milestone record
    (map-set milestones
      { milestone-id: milestone-id }
      {
        researcher: tx-sender,
        title: title,
        description: description,
        milestone-type: milestone-type,
        status: STATUS-SUBMITTED,
        submission-time: stacks-block-height,
        verification-deadline: verification-deadline,
        ipfs-hash: ipfs-hash,
        required-field: required-field,
        approval-count: u0,
        rejection-count: u0,
        total-verifications: u0
      }
    )
    
    ;; Increment milestone ID for next submission
    (var-set next-milestone-id (+ milestone-id u1))
    
    (ok milestone-id)
  )
)

;; Expert verification of a milestone
(define-public (verify-milestone
               (milestone-id uint)
               (decision uint)
               (comments (string-utf8 500)))
  (let
    ((milestone-data (unwrap! (map-get? milestones { milestone-id: milestone-id }) (err ERR-DOES-NOT-EXIST)))
     (expert-verification (map-get? milestone-verifications { milestone-id: milestone-id, expert: tx-sender })))
    
    ;; Check if expert is verified (this would call the expert contract)
    ;; For now, we'll assume this check passes - in real implementation:
    ;; (asserts! (unwrap! (contract-call? (var-get expert-contract) is-verified tx-sender) (err ERR-NOT-EXPERT)) (err ERR-NOT-EXPERT))
    
    ;; Validate decision
    (asserts! (or 
               (is-eq decision DECISION-APPROVE)
               (is-eq decision DECISION-REJECT)
               (is-eq decision DECISION-REQUEST-REVISION)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Check milestone is still under review or submitted
    (asserts! (or 
               (is-eq (get status milestone-data) STATUS-SUBMITTED)
               (is-eq (get status milestone-data) STATUS-UNDER-REVIEW)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Check verification deadline hasn't passed
    (asserts! (< stacks-block-height (get verification-deadline milestone-data)) (err ERR-INVALID-STATUS))
    
    ;; Check expert hasn't already verified this milestone
    (asserts! (is-none expert-verification) (err ERR-ALREADY-VERIFIED))
    
    ;; Record expert verification
    (map-set milestone-verifications
      { milestone-id: milestone-id, expert: tx-sender }
      {
        decision: decision,
        comments: comments,
        verification-time: stacks-block-height
      }
    )
    
    ;; Update milestone counts and status
    (let
      ((new-approval-count (if (is-eq decision DECISION-APPROVE) 
                              (+ (get approval-count milestone-data) u1)
                              (get approval-count milestone-data)))
       (new-rejection-count (if (is-eq decision DECISION-REJECT)
                               (+ (get rejection-count milestone-data) u1)
                               (get rejection-count milestone-data)))
       (new-total-verifications (+ (get total-verifications milestone-data) u1)))
      
      ;; Determine new status
      (let
        ((new-status (if (>= new-approval-count REQUIRED-VERIFICATIONS)
                        STATUS-VERIFIED
                        (if (>= new-rejection-count REQUIRED-VERIFICATIONS)
                           STATUS-REJECTED
                           STATUS-UNDER-REVIEW))))
        
        ;; Update milestone
        (map-set milestones
          { milestone-id: milestone-id }
          (merge milestone-data {
            status: new-status,
            approval-count: new-approval-count,
            rejection-count: new-rejection-count,
            total-verifications: new-total-verifications
          })
        )
        
        ;; If milestone is verified, increment expert verification count
        ;; (if (is-eq new-status STATUS-VERIFIED)
        ;;   (contract-call? (var-get expert-contract) increment-verification-count tx-sender)
        ;;   (ok true))
        
        (ok new-status)
      )
    )
  )
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (match (map-get? milestones { milestone-id: milestone-id })
    milestone-data (ok milestone-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get expert verification for a milestone
(define-read-only (get-milestone-verification (milestone-id uint) (expert principal))
  (match (map-get? milestone-verifications { milestone-id: milestone-id, expert: expert })
    verification-data (ok verification-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get milestones by researcher
(define-read-only (get-researcher-milestones (researcher principal))
  ;; In a real implementation, this would use an index
  ;; For now, return a placeholder
  (ok researcher)
)

;; Get milestones by status
(define-read-only (get-milestones-by-status (status uint))
  ;; In a real implementation, this would use an index
  ;; For now, return a placeholder
  (ok status)
)

;; Update milestone status (admin function)
(define-public (update-milestone-status (milestone-id uint) (new-status uint))
  (let
    ((milestone-data (unwrap! (map-get? milestones { milestone-id: milestone-id }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only contract owner can manually update status
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Validate status
    (asserts! (or 
               (is-eq new-status STATUS-SUBMITTED)
               (is-eq new-status STATUS-UNDER-REVIEW)
               (is-eq new-status STATUS-VERIFIED)
               (is-eq new-status STATUS-REJECTED)
               (is-eq new-status STATUS-DISPUTED)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Update milestone status
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone-data { status: new-status })
    )
    
    (ok true)
  )
)

;; Extend verification deadline (admin function)
(define-public (extend-deadline (milestone-id uint) (new-deadline uint))
  (let
    ((milestone-data (unwrap! (map-get? milestones { milestone-id: milestone-id }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only contract owner can extend deadlines
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; New deadline must be in the future
    (asserts! (> new-deadline stacks-block-height) (err ERR-INVALID-STATUS))
    
    ;; Update deadline
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone-data { verification-deadline: new-deadline })
    )
    
    (ok true)
  )
)

;; Check if milestone is verified
(define-read-only (is-milestone-verified (milestone-id uint))
  (match (map-get? milestones { milestone-id: milestone-id })
    milestone-data (ok (is-eq (get status milestone-data) STATUS-VERIFIED))
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Get current milestone ID counter
(define-read-only (get-next-milestone-id)
  (ok (var-get next-milestone-id))
)