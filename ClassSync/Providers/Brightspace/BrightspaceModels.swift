import Foundation

struct BrightspacePagingInfo: Decodable, Sendable {
    let bookmark: String?
    let hasMoreItems: Bool

    private enum CodingKeys: String, CodingKey {
        case bookmark = "Bookmark"
        case hasMoreItems = "HasMoreItems"
    }
}

struct BrightspacePagedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let pagingInfo: BrightspacePagingInfo
    let items: [Item]

    private enum CodingKeys: String, CodingKey {
        case pagingInfo = "PagingInfo"
        case items = "Items"
    }
}

struct BrightspaceObjectListPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let next: String?
    let objects: [Item]

    private enum CodingKeys: String, CodingKey {
        case next = "Next"
        case objects = "Objects"
    }
}

struct BrightspaceOrgUnitType: Decodable, Sendable {
    let id: Int
    let code: String
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case code = "Code"
        case name = "Name"
    }
}

struct BrightspaceOrgUnit: Decodable, Sendable {
    let id: Int
    let type: BrightspaceOrgUnitType
    let name: String
    let code: String?
    let homeURL: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case type = "Type"
        case name = "Name"
        case code = "Code"
        case homeURL = "HomeUrl"
    }
}

struct BrightspaceEnrollmentAccess: Decodable, Sendable {
    let isActive: Bool
    let canAccess: Bool
    let startDate: String?
    let endDate: String?

    private enum CodingKeys: String, CodingKey {
        case isActive = "IsActive"
        case canAccess = "CanAccess"
        case startDate = "StartDate"
        case endDate = "EndDate"
    }
}

struct BrightspaceEnrollment: Decodable, Sendable {
    let orgUnit: BrightspaceOrgUnit
    let access: BrightspaceEnrollmentAccess

    private enum CodingKeys: String, CodingKey {
        case orgUnit = "OrgUnit"
        case access = "Access"
    }

    var isCourseOffering: Bool {
        let type = "\(orgUnit.type.code) \(orgUnit.type.name)"
            .lowercased()
            .filter(\.isLetter)
        return type.contains("courseoffering")
    }
}

struct BrightspaceAssociatedEntity: Decodable, Sendable {
    let type: String
    let id: Int
    let link: String?

    private enum CodingKeys: String, CodingKey {
        case type = "AssociatedEntityType"
        case id = "AssociatedEntityId"
        case link = "Link"
    }
}

struct BrightspaceCalendarEvent: Decodable, Sendable {
    let id: Int
    let orgUnitID: Int
    let title: String
    let startDateTime: String?
    let startDay: String?
    let orgUnitName: String
    let orgUnitCode: String
    let associatedEntity: BrightspaceAssociatedEntity?
    let viewURL: String?
    let eventType: Int?

    private enum CodingKeys: String, CodingKey {
        case id = "CalendarEventId"
        case orgUnitID = "OrgUnitId"
        case title = "Title"
        case startDateTime = "StartDateTime"
        case startDay = "StartDay"
        case orgUnitName = "OrgUnitName"
        case orgUnitCode = "OrgUnitCode"
        case associatedEntity = "AssociatedEntity"
        case viewURL = "CalendarEventViewUrl"
        case eventType = "EventType"
    }
}

struct BrightspaceDropboxFolder: Decodable, Sendable {
    let id: Int
    let name: String
    let dueDate: String?
    let isHidden: Bool

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case dueDate = "DueDate"
        case isHidden = "IsHidden"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }
}

struct BrightspaceEntityDropbox: Decodable, Sendable {
    let status: String
    let submissions: [BrightspaceSubmission]

    private enum CodingKeys: String, CodingKey {
        case status = "Status"
        case submissions = "Submissions"
    }
}

struct BrightspaceSubmission: Decodable, Sendable {
    let id: Int
    let submissionDate: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case submissionDate = "SubmissionDate"
    }
}
