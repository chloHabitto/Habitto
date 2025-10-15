//
//  FirestoreError.swift
//  Habitto
//
//  Firestore-specific error types
//

import Foundation

enum FirestoreError: LocalizedError {
  case notAuthenticated
  case userNotAuthenticated
  case documentNotFound
  case invalidData
  case operationFailed(String)
  case networkError(Error)
  
  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "User is not authenticated"
    case .userNotAuthenticated:
      return "User is not authenticated"
    case .documentNotFound:
      return "Document not found"
    case .invalidData:
      return "Invalid data format"
    case .operationFailed(let message):
      return "Operation failed: \(message)"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }
}
