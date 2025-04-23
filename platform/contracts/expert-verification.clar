
;; Expert Verification Contract
;; This contract manages the registration and verification of experts who can validate research milestones

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-EXISTS u2)
(define-constant ERR-DOES-NOT-EXIST u3)
(define-constant ERR-INVALID-STATUS u4)

;; Expert trait - to be implemented by contracts that verify experts
(define-trait expert-trait
  (
    ;; Check if a principal is a verified expert
    (is-verified (principal) (response bool uint))
  )
)

;; Expert status constants
(define-constant STATUS-INACTIVE u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-SUSPENDED u2)

;; Expert fields
(define-constant FIELD-SCIENTIFIC u1)
(define-constant FIELD-HUMANITIES u2)
(define-constant FIELD-ENGINEERING u3)
(define-constant FIELD-MEDICAL u4)
(define-constant FIELD-OTHER u5)

;; Expert specialization record
(define-map experts 
  { expert: principal } 
  {
    name: (string-utf8 100),
    credentials: (string-utf8 500),
    field: uint,
    status: uint,
    verification-count: uint,
    registration-time: uint
  }
)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

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

;; Register as an expert
(define-public (register-expert 
               (name (string-utf8 100))
               (credentials (string-utf8 500))
               (field uint))
  (let
     ((current-time u0)) 

    ;; Validate field
    (asserts! (or 
               (is-eq field FIELD-SCIENTIFIC)
               (is-eq field FIELD-HUMANITIES)
               (is-eq field FIELD-ENGINEERING)
               (is-eq field FIELD-MEDICAL)
               (is-eq field FIELD-OTHER)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Expert doesn't already exist
    (asserts! (is-none (map-get? experts { expert: tx-sender })) (err ERR-ALREADY-EXISTS))
    
    ;; Create expert entry (pending approval)
    (map-set experts 
      { expert: tx-sender }
      {
        name: name,
        credentials: credentials,
        field: field,
        status: STATUS-INACTIVE,
        verification-count: u0,
        registration-time: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Approve an expert
(define-public (approve-expert (expert-principal principal))
  (let
    ((expert-data (unwrap! (map-get? experts { expert: expert-principal }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only the contract owner can approve experts
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Update expert status
    (map-set experts 
      { expert: expert-principal }
      (merge expert-data { status: STATUS-ACTIVE })
    )
    
    (ok true)
  )
)

;; Suspend an expert
(define-public (suspend-expert (expert-principal principal))
  (let
    ((expert-data (unwrap! (map-get? experts { expert: expert-principal }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only the contract owner can suspend experts
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Update expert status
    (map-set experts 
      { expert: expert-principal }
      (merge expert-data { status: STATUS-SUSPENDED })
    )
    
    (ok true)
  )
)

;; Get expert details
(define-read-only (get-expert (expert-principal principal))
  (match (map-get? experts { expert: expert-principal })
    expert-data (ok expert-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Check if principal is a valid expert
(define-public (is-verified (expert-principal principal))
  (match (map-get? experts { expert: expert-principal })
    expert-data (ok (is-eq (get status expert-data) STATUS-ACTIVE))
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Update expert credentials
(define-public (update-credentials (credentials (string-utf8 500)))
  (let
    ((expert-data (unwrap! (map-get? experts { expert: tx-sender }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Update credentials
    (map-set experts 
      { expert: tx-sender }
      (merge expert-data { credentials: credentials })
    )
    
    (ok true)
  )
)

;; Update expert field
(define-public (update-field (field uint))
  (let
    ((expert-data (unwrap! (map-get? experts { expert: tx-sender }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Validate field
    (asserts! (or 
               (is-eq field FIELD-SCIENTIFIC)
               (is-eq field FIELD-HUMANITIES)
               (is-eq field FIELD-ENGINEERING)
               (is-eq field FIELD-MEDICAL)
               (is-eq field FIELD-OTHER)
              ) 
              (err ERR-INVALID-STATUS))
    
    ;; Update field
    (map-set experts 
      { expert: tx-sender }
      (merge expert-data { field: field })
    )
    
    (ok true)
  )
)

;; Increment verification count - called by research contract
(define-public (increment-verification-count (expert-principal principal))
  (let
    ((expert-data (unwrap! (map-get? experts { expert: expert-principal }) (err ERR-DOES-NOT-EXIST))))
    
    ;; Only allow this to be called by authorized contracts
    ;; In a real implementation, you would check against an allowed list of contracts
    ;; (asserts! (is-some (index-of? (var-get allowed-contracts) contract-caller)) (err ERR-NOT-AUTHORIZED))
    
    ;; Update verification count
    (map-set experts 
      { expert: expert-principal }
      (merge expert-data { verification-count: (+ (get verification-count expert-data) u1) })
    )
    
    (ok true)
  )
)

;; Get experts by field
(define-read-only (get-experts-by-field (field uint))
  ;; This would be implemented with an index in a real system
  ;; For now, just an example placeholder
  (ok field)
)