//
//  ClientDTO.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import Vapor

enum ClientTypeDTO: String, Content {
    case professional = "Professionnel"
    case individual = "Particulier"
}

struct ClientDTO: Content {
    let reference: String
    let type: ClientTypeDTO
    let company: String?
    let siret: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let address: String?
    let cp: String?
    let city: String?
    let note: String?
    let accountantId: String?
}
