;; Contract Registry
;; This contract serves as a registry for other contracts in the system

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-EXISTS u2)
(define-constant ERR-DOES-NOT-EXIST u3)

;; Map of registered contracts
(define-map contracts 
  { contract-name: principal } 
  { 
    contract-type: (string-utf8 100),
    description: (string-utf8 500),
    verified: bool 
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

;; Register a contract
(define-public (register-contract 
               (contract-name principal)
               (contract-type (string-utf8 100))
               (description (string-utf8 500)))
  (begin
    ;; Only the contract owner can register contracts
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Contract doesn't already exist
    (asserts! (is-none (map-get? contracts { contract-name: contract-name })) (err ERR-ALREADY-EXISTS))
    
    ;; Register the contract
    (map-set contracts 
      { contract-name: contract-name }
      {
        contract-type: contract-type,
        description: description,
        verified: true
      }
    )
    
    (ok true)
  )
)

;; Update a contract
(define-public (update-contract 
               (contract-name principal)
               (contract-type (string-utf8 100))
               (description (string-utf8 500))
               (verified bool))
  (begin
    ;; Only the contract owner can update contracts
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Contract must exist
    (asserts! (is-some (map-get? contracts { contract-name: contract-name })) (err ERR-DOES-NOT-EXIST))
    
    ;; Update the contract
    (map-set contracts 
      { contract-name: contract-name }
      {
        contract-type: contract-type,
        description: description,
        verified: verified
      }
    )
    
    (ok true)
  )
)

;; Remove a contract
(define-public (remove-contract (contract-name principal))
  (begin
    ;; Only the contract owner can remove contracts
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    ;; Contract must exist
    (asserts! (is-some (map-get? contracts { contract-name: contract-name })) (err ERR-DOES-NOT-EXIST))
    
    ;; Remove the contract
    (map-delete contracts { contract-name: contract-name })
    
    (ok true)
  )
)

;; Get contract details
(define-read-only (get-contract (contract-name principal))
  (match (map-get? contracts { contract-name: contract-name })
    contract-data (ok contract-data)
    (err ERR-DOES-NOT-EXIST)
  )
)

;; Check if contract is verified
(define-read-only (is-verified (contract-name principal))
  (match (map-get? contracts { contract-name: contract-name })
    contract-data (ok (get verified contract-data))
    (err ERR-DOES-NOT-EXIST)
  )
)