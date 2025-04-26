;; Botanical Specimen Catalog Smart Contract
;; Provides a comprehensive system for indexing, managing and sharing botanical specimens 
;; with appropriate access controls for scientific collaboration



;; System Constants and Error Codes
(define-constant SYSTEM_ADMINISTRATOR tx-sender)
(define-constant ERR_UNAUTHORIZED_ACTION (err u300))
(define-constant ERR_SPECIMEN_NOT_FOUND (err u301))
(define-constant ERR_SPECIMEN_DUPLICATE_ENTRY (err u302))
(define-constant ERR_INVALID_SPECIMEN_TITLE (err u303))
(define-constant ERR_INVALID_SPECIMEN_SIZE (err u304))
(define-constant ERR_ACCESS_RESTRICTED (err u305))

;; Global Counter Management
(define-data-var specimen-index uint u0)

;; Primary Data Structure for Specimen Records
(define-map botanical-specimens
  { specimen-id: uint }
  {
    specimen-title: (string-ascii 80),
    specimen-collector: principal,
    specimen-size: uint,
    collection-block: uint,
    specimen-description: (string-ascii 256),
    classification-labels: (list 8 (string-ascii 40))
  }
)

;; Access Control Mapping
(define-map specimen-access-rights
  { specimen-id: uint, researcher: principal }
  { can-examine: bool }
)

;; Helper Functions for Validation and State Checking

;; Checks if specimen record exists in database
(define-private (specimen-record-exists (specimen-id uint))
  (is-some (map-get? botanical-specimens { specimen-id: specimen-id }))
)
