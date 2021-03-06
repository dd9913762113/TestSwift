
import Foundation
import SwiftSignalKit



public struct InactiveChannel : Equatable {
    public let peer: Peer
    public let lastActivityDate: Int32
    public let participantsCount: Int32?
    
    init(peer: Peer, lastActivityDate: Int32, participantsCount: Int32?) {
        self.peer = peer
        self.lastActivityDate = lastActivityDate
        self.participantsCount = participantsCount
    }
    public static func ==(lhs: InactiveChannel, rhs: InactiveChannel) -> Bool {
        return lhs.peer.isEqual(rhs.peer) && lhs.lastActivityDate == rhs.lastActivityDate && lhs.participantsCount == rhs.participantsCount
    }
}

func _internal_inactiveChannelList(network: Network) -> Signal<[InactiveChannel], NoError> {
    return network.request(Api.functions.channels.getInactiveChannels())
    |> retryRequest
    |> map { result in
        switch result {
        case let .inactiveChats(dates, chats, users):
            let channels = chats.compactMap {
                parseTelegramGroupOrChannel(chat: $0)
            }
            var participantsCounts: [PeerId: Int32] = [:]
            for chat in chats {
                switch chat {
                case let .channel(channel):
                    if let participantsCountValue = channel.participantsCount {
                        participantsCounts[chat.peerId] = channel.participantsCount
                    }
                default:
                    break
                }
            }
            var inactive: [InactiveChannel] = []
            for (i, channel) in channels.enumerated() {
                inactive.append(InactiveChannel(peer: channel, lastActivityDate: dates[i], participantsCount: participantsCounts[channel.id]))
            }
            return inactive
        }
    }
}
