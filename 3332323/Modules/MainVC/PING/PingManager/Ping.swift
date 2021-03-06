//
//  NewPing.swift
//  ThreeTab
//
//  Created by wenyu on 2018/11/14.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

import Foundation
import Foundation.NSTimer

let kPendingPingsCleanupGrace : TimeInterval = 1.0
let kDefaultPayloadSize = 56
let kDefaultTTL = 49
let kDefaultPingPeriod : TimeInterval = 1.0
let kDefaultTimeout : TimeInterval = 2.0

@objc public protocol PingDelegate{
    
    
    @objc optional func ping(_ pinger: Ping, didFailWithError error: Error)
    @objc optional func ping(_ pinger: Ping, didTimeoutWith result: PingResult)
    @objc optional func ping(_ pinger: Ping, didSendPingWith result: PingResult)
    @objc optional func ping(_ pinger: Ping, didReceiveReplyWith result: PingResult)
    @objc optional func ping(_ pinger: Ping, didReceiveUnexpectedReplyWith result: PingResult)
    @objc optional func ping(_ pinger: Ping, didFailToSendPingWith result: PingResult, error: Error)
    func stop(_ ping:Ping)
}

public class Ping : NSObject {
    
    public static var pingThreadCount = 0
    
    public var pingThreadCount = 0
    public weak var delegate : PingDelegate?
    
    public var host : String?
    public var pingPeriod : TimeInterval = 1
    public var timeout : TimeInterval = 1
    public var payloadSize : Int = kDefaultPayloadSize
    public var ttl : UInt = 0
    
    public var isPinging : Bool = false
    public var isReady : Bool = false
    public var debug : Bool = false
    public var hostAddressString : String?
    public var pendingPings = [String:PingResult]()
    public var hostAddress : Data?
    public var identifier : UInt16 = 0
    public var nextSequenceNumber : UInt = 0
    public var timeoutTimers = [String:Foundation.Timer]()
    public var socketNum : Int32 = 0
    public var isStopped = true
    
    public override init() {
        super.init()
        
        initValue()

    }
    public init(_ host:String){
        super.init()
        initValue()
        self.host = host
    }
    private func initValue(){
        self.identifier = UInt16(truncatingIfNeeded: arc4random())
        Ping.pingThreadCount += 1
        pingThreadCount = Ping.pingThreadCount
    }
    
    
    public func startPinging() {
        self.isPinging = true
    }
    private static var pingQueue = DispatchQueue.init(label: "pingQueue")
    private var sendQueue = Ping.pingQueue
    private lazy var lisentQueue = DispatchQueue(label: "\(self).lisentQueue")
   
    
    func Delegate(_ delegate:PingDelegate?) -> Ping{
        self.delegate = delegate
        return self
    }
    public func stop() {
        if self.isPinging,let stop = self.delegate?.stop{
            self.isPinging = false
            stop(self)
        }
    }
    
    public func send() {
        sendQueue.async {[weak self] in
            self?.sendPacket()
        }
        
    }
    public func listenOnce() {
        lisentQueue.async {[weak self] in
            self?.listenPacket()
        }
        
        
    }
    deinit {
      
        //        NSLog("PingCount:"+Ping.pingThreadCount.description)
    }
    let INET6_ADDRSTRLEN = 64
    
    
    static func icmp4HeaderOffsetInPacket(_ packet : Data) -> UInt{
        var result : UInt
        var ipPtr : IPHeader
        //    const struct IPHeader * ipPtr;
        var ipHeaderLength : size_t
        result = UInt(NSNotFound)
        if packet.count >= MemoryLayout<IPHeader>.size + MemoryLayout<ICMPHeader>.size{
            ipPtr = packet.bytes.bindMemory(to: IPHeader.self, capacity:packet.count).pointee
            
            assert((ipPtr.versionAndHeaderLength & 0xF0) == 0x40)
            assert(ipPtr.ptl == 1)
            ipHeaderLength = Int((ipPtr.versionAndHeaderLength & 0x0F)) * MemoryLayout<UInt32>.size
            if packet.count >= ipHeaderLength + MemoryLayout<ICMPHeader>.size{
                result = UInt(ipHeaderLength)
            }
        }
        return result
    }
    static func icmp4InPacket(_ packet:Data) -> ICMPHeader?{
        var result : ICMPHeader? = nil
        var icmpHeaderOffset : UInt
        
        icmpHeaderOffset = self.icmp4HeaderOffsetInPacket(packet)
        if icmpHeaderOffset != NSNotFound {
            let uint8Bytes = packet.bytes.bindMemory(to: UInt8.self, capacity: packet.count) + Int(icmpHeaderOffset)
            
            let bytes = UnsafeRawPointer(uint8Bytes).bindMemory(to: ICMPHeader.self, capacity: packet.count - Int(icmpHeaderOffset))
            
            result = bytes.pointee
        }
        return result
    }
    static func sourceAddressInPacket(_ packet:Data) ->String?{
        // Returns the source address of the IP packet
        var ipPtr : UnsafePointer<IPHeader>
        if packet.count >= MemoryLayout<IPHeader>.size{
            ipPtr = packet.bytes.bindMemory(to: IPHeader.self, capacity: packet.count)
            
            let sourceAddress = ipPtr.pointee.sourceAddress//dont need to swap byte order those cuz theyre the smallest atomic unit (1 byte)
            let ipString = "\(sourceAddress.0).\(sourceAddress.1).\(sourceAddress.2).\(sourceAddress.3)"
            
            return ipString
        }
        return nil;
    }
    // This is the standard BSD checksum code, modified to use modern types.
    
    var hostAddressFamily : sa_family_t {
        get{
            var result : sa_family_t = sa_family_t(AF_UNSPEC)
            if let hostAddress = self.hostAddress, hostAddress.count >= MemoryLayout<sockaddr>.size{
                result = hostAddress.bytes.bindMemory(to: sockaddr.self, capacity: hostAddress.count).pointee.sa_family
            }
            return result
        }
    }
    // Returns true if the packet looks like a valid ping response packet destined
    // for us.
    enum kICMPv4Type : UInt8{
        
        case EchoRequest = 8
        case EchoReply   = 0
    }
    enum kICMPv6Type : UInt8{
        case EchoRequest = 128
        case EchoReply   = 129
    }
    func isValidPing4ResponsePacket(_ packet : Data) -> Bool{
        let packet = packet
        var result = false
        var icmpHeaderOffset : UInt
        var icmpPtr : UnsafeMutablePointer<ICMPHeader>
        var receivedChecksum:UInt16
        var calculatedChecksum:UInt16
        
        icmpHeaderOffset = Ping.icmp4HeaderOffsetInPacket(packet)
        
        if icmpHeaderOffset != NSNotFound{
            let uInt8poiner = packet.bytes.bindMemory(to: UInt8.self, capacity: packet.count) + Int(icmpHeaderOffset)
            let pointer = UnsafeMutableRawPointer(mutating: uInt8poiner).bindMemory(to: ICMPHeader.self, capacity: packet.count - Int(icmpHeaderOffset))
            
            icmpPtr = pointer
            //    icmpPtr = (struct ICMPHeader *) (((uint8_t *)[packet mutableBytes]) + icmpHeaderOffset);
            receivedChecksum = icmpPtr.pointee.checksum
            icmpPtr.pointee.checksum  = 0
            calculatedChecksum = in_cksum(icmpPtr, packet.count - Int(icmpHeaderOffset))
            icmpPtr.pointee.checksum  = receivedChecksum
            
            if receivedChecksum == calculatedChecksum{
                if icmpPtr.pointee.type == kICMPv4Type.EchoReply.rawValue, icmpPtr.pointee.code == 0 {
                    
                    if CFSwapInt16(icmpPtr.pointee.identifier) == self.identifier  {
                        if CFSwapInt16(icmpPtr.pointee.sequenceNumber) < self.nextSequenceNumber{
                            result = true
                        }
                    }
                }
            }
        }
        return result
    }
    
    // Returns true if the IPv6 packet looks like a valid ping response packet destined
    // for us.
    func isValidPing6ResponsePacket(_ packet:Data)->Bool{
        var result = false
        var icmpPtr : UnsafePointer<ICMPHeader>
        
        if packet.count >= MemoryLayout<ICMPHeader>.size {
            icmpPtr = packet.bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count)
            if icmpPtr.pointee.type == kICMPv4Type.EchoReply.rawValue,icmpPtr.pointee.code == 0{
                if CFSwapInt16(icmpPtr.pointee.identifier) == self.identifier{
                    if CFSwapInt16(icmpPtr.pointee.sequenceNumber) < self.nextSequenceNumber{
                        result = true
                    }
                }
            }
        }
        return result
        
    }
    func isValidPingResponsePacket(_ packet: Data)->Bool{
        var result : Bool
        
        switch self.hostAddressFamily{
        case sa_family_t(AF_INET):
            result = self.isValidPing4ResponsePacket(packet)
            break
        case sa_family_t(AF_INET6):
            result = self.isValidPing6ResponsePacket(packet)
            break
        default:
            result = false
            break
        }
        return result
    }
    
    
    func listenPacket(){
        
        let kBufferSize = 65535
        guard let buffer = malloc(kBufferSize) else {
            self.delegate?.ping?(self, didFailWithError: NSError(domain: "", code: -1, userInfo: nil) as Error)
            return
        }
        var err : Int
        var ss = [sockaddr_storage()]
        var addrLen : socklen_t
        var bytesRead : ssize_t
        
        
        //read the data.
        addrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        
        
        let addrSockaddr = ss.withUnsafeMutableBytes{$0.baseAddress}.unsafelyUnwrapped.bindMemory(to: sockaddr.self, capacity: Int(addrLen))
        
        var tv : timeval = .init(tv_sec: __darwin_time_t(3), tv_usec: 0)
        let value = setsockopt(self.socketNum, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size));
        if value == 0{
            bytesRead = recvfrom(self.socketNum, buffer, kBufferSize, 0, addrSockaddr, &addrLen)
        }else{
            bytesRead = -1
        }
        err = 0;
        if bytesRead < 0 {
            err = -1;
        }
        
        //process the data we read.
        if bytesRead > 0 {
            var hoststr = CChar()
            //            char hoststr[INET6_ADDRSTRLEN];
            var sin : sockaddr_in = UnsafeMutableRawPointer(addrSockaddr).bindMemory(to: sockaddr_in.self, capacity: Int(addrLen)).pointee
            inet_ntop(Int32(sin.sin_family), &(sin.sin_addr), &hoststr, socklen_t(INET6_ADDRSTRLEN))
            //            struct sockaddr_in *sin = (struct sockaddr_in *)&addr;
            //            inet_ntop(sin->sin_family, &(sin->sin_addr), hoststr, INET6_ADDRSTRLEN);
            let host = String(utf8String: &hoststr)
            
            if(host == hostAddressString) { // only make sense where received packet comes from expected source
                
                let receiveDate = Date()
                let packet = Data(bytes: buffer, count: bytesRead)
                
                //                assert((packet));
                
                //complete the ping result
                //                const struct ICMPHeader *headerPointer;
                var headerPointer : ICMPHeader?
                
                if sin.sin_family == AF_INET{
                    headerPointer = Ping.icmp4InPacket(packet)
                } else {
                    headerPointer = packet.bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count).pointee
                    
                }
                
                let segNo = CFSwapInt16(headerPointer!.sequenceNumber)
                //                NSUInteger seqNo = (NSUInteger)OSSwapBigToHostInt16(headerPointer->sequenceNumber);
                let key = segNo.description
                //                NSNumber *key = @(seqNo);
                
                //                PingResult *pingResult = [(PingResult *)self.pendingPings[key] copy];
                
                if let pingResult =  sendQueue.sync(execute: {self.pendingPings[key]?.copy()}){
                    
                    if self.isValidPingResponsePacket(packet){
                        //override the source address (we might have sent to google.com and 172.123.213.192 replied)
                        pingResult.receiveDate = receiveDate
                        // IP can't be read from header for ICMPv6
                        if sin.sin_family == sa_family_t(AF_INET) {
                            
                            pingResult.host = Ping.sourceAddressInPacket(packet)
                            
                            //set ttl from response (different servers may respond with different ttls)
                            let ipPtr : UnsafePointer<IPHeader>
                            
                            if packet.count >= MemoryLayout<IPHeader>.size {
                                
                                ipPtr = packet.bytes.bindMemory(to: IPHeader.self, capacity: packet.count)
                                pingResult.ttl = UInt(ipPtr.pointee.timeToLive);
                            }
                        }
                        
                        pingResult.pingStatus = .success
                        
                        sendQueue.async {[weak self] in
                            guard let self = self else{return}
                            let timer = self.timeoutTimers[key]
                            timer?.invalidate()
                            self.timeoutTimers.removeValue(forKey: key)
                            self.delegate?.ping?(self, didReceiveReplyWith: pingResult)
                            
                        }
                        
                    }else {
                        pingResult.pingStatus = .fail
                        delegate?.ping?(self, didReceiveUnexpectedReplyWith: pingResult)
                        
                    }
                }
            }
        }
        else {
            
            //we failed to read the data, so shut everything down.
            if (err == 0) {
                err = Int(EPIPE);
            }
            
            if self.isStopped{
                delegate?.ping?(self, didFailWithError: NSError.init(domain: NSPOSIXErrorDomain, code: err, userInfo: nil))
            }
            self.stop()
        }
        free(buffer)
    }
    
    func generateDataWithLength(_ length:Int) -> Data {
        //create a buffer full of 7's of specified length
        let tempBuffer = [UInt8].init(repeating: 7, count: length)
        //        memset(&tempBuffer, 7, Int(length))
        
        return Data(bytes: tempBuffer)
    }
    func pingPacketWithType(_ type: UInt8, _ payload:Data ,_ requiresChecksum:Bool)  -> NSData{
        var packet: NSMutableData
        var icmpPtr : UnsafeMutablePointer<ICMPHeader>
        
        packet = NSMutableData(length: MemoryLayout<ICMPHeader>.size + payload.count)!
        
        icmpPtr = packet.mutableBytes.bindMemory(to: ICMPHeader.self, capacity: packet.length)
        icmpPtr.pointee.type = type
        icmpPtr.pointee.code = 0
        icmpPtr.pointee.checksum = 0
        icmpPtr.pointee.identifier  = CFSwapInt16(self.identifier)
        icmpPtr.pointee.sequenceNumber = CFSwapInt16(UInt16(self.nextSequenceNumber))
        memcpy(&icmpPtr[1], payload.bytes, payload.count);
        if requiresChecksum {
            // The IP checksum routine returns a 16-bit number that's already in correct byte order
            // (due to wacky 1's complement maths), so we just put it into the packet as a 16-bit unit.
            
            icmpPtr.pointee.checksum = in_cksum(packet.bytes, packet.length)
        }
        return packet
        
    }
    func sendPacket(){
        if self.isPinging {
            
            weak var weakSelf = self
            var err :Int
            var packet: NSData = NSData()
            var bytesSent:ssize_t
            
            // Construct the ping packet.
            let payload = self.generateDataWithLength(self.payloadSize)
            
            let hostAddressFamily = self.hostAddressFamily
            switch hostAddressFamily{
            case sa_family_t(AF_INET):
                packet = self.pingPacketWithType(kICMPv4Type.EchoRequest.rawValue, payload, true)
                break
            case sa_family_t(AF_INET6):
                packet = pingPacketWithType(kICMPv6Type.EchoRequest.rawValue, payload, true)
                break
                
            default:
                break
            }
            
            let newPingResult = PingResult()
            
            // Send the packet.
            if self.socketNum == 0{
                bytesSent = -1
                err = Int(EBADF)
            }else{
                
                //record the send date
                let sendDate = Date()
                
                //construct ping result, as much as it can
                newPingResult.sequenceNumber = self.nextSequenceNumber
                newPingResult.host = self.host
                newPingResult.sendDate = sendDate
                newPingResult.ttl = self.ttl
                newPingResult.payloadSize = UInt(self.payloadSize)
                newPingResult.pingStatus = .pending
                
                //add it to pending pings
                let key = self.nextSequenceNumber.description
                self.pendingPings[key] = newPingResult
                
                //increment sequence number
                self.nextSequenceNumber += 1
                
                //we create a copy, this one will be passed out to other threads
                let pingResultCopy : PingResult = newPingResult.copy()
                
                //we need to clean up our list of pending pings, and we do that after the timeout has elapsed (+ some grace period)
                
                sendQueue.asyncAfter(deadline: DispatchTime.now() + (self.timeout + kPendingPingsCleanupGrace) * Double(NSEC_PER_SEC)) {
                    weakSelf?.pendingPings.removeValue(forKey: key)
                }
                
                
                //add a timeout timer
                //add a timeout timer
                
                let timeoutTimer = Foundation.Timer(timeInterval: self.timeout, target: BlockOperation(block: {[weak self] in
                    
                    guard let self = self else{return}
                    newPingResult.pingStatus = .fail
                    self.sendQueue.async {
                        weakSelf?.delegate?.ping?(self, didTimeoutWith: pingResultCopy)
                        
                    }
                    self.sendQueue.async {
                        weakSelf?.timeoutTimers.removeValue(forKey: key)
                    }
                    
                }), selector: #selector(BlockOperation.main), userInfo: nil, repeats: false)
                
                RunLoop.main.add(timeoutTimer, forMode: .common)
                
                self.timeoutTimers[key] = timeoutTimer
                //keep a local ref to it
                self.delegate?.ping?(self, didSendPingWith: pingResultCopy)
                let hostAddress = self.hostAddress ?? .init()
                bytesSent = sendto(self.socketNum, packet.bytes, packet.length, 0, hostAddress.bytes.bindMemory(to: sockaddr.self, capacity: hostAddress.count), socklen_t(hostAddress.count))
                err = 0
                if bytesSent < 0 {
                    err = Int(errno)
                }
                if bytesSent > 0,Int(bytesSent) == packet.length {
                    //noop, we already notified delegate about sending of the ping
                }else{
                    //complete the error
                    if (err == 0) {
                        err = Int(ENOBUFS)    // This is not a hugely descriptor error, alas.
                    }
                    
                    //little log
                    if (self.debug) {
                        NSLog("Ping: failed to send packet with error code: %d", err)
                    }
                    
                    //change status
                    newPingResult.pingStatus = .fail
                    let pingReultCopyAfterFailure : PingResult = newPingResult.copy()
                    
                    delegate?.ping?(self, didFailToSendPingWith: pingReultCopyAfterFailure, error: NSError(domain: NSPOSIXErrorDomain, code: err, userInfo: nil))
                }
            }
        }
    }
    
    public func setup(_ callBack: @escaping (_ success:Bool,_ error:Error?)->Void) {
        //error out of its already setup
        if self.isReady{
            if self.debug{
                NSLog("Ping: Can't setup, already setup.")
            }
            callBack(false,nil)
            return
        }
        
        //error out if no host is set
        if self.host == nil{
            if self.debug{
                NSLog("Ping: set host before attempting to start.")
            }
            callBack(false,nil)
            return
        }
        
        //set up data structs
        self.nextSequenceNumber = 0
        
        var streamError = CFStreamError()
        var success : Bool
        let hostName = CFHostCreateWithName(nil,(self.host ?? "") as CFString).autorelease()
        let hostRef : CFHost? = hostName.takeUnretainedValue()
        
        
        if hostRef != nil{
            success = CFHostStartInfoResolution(hostRef!, CFHostInfoType.addresses, &streamError)
        }else{
            success = false
        }
        
        
        if !success {
            //construct an error
            var userInfo : [String:Any] = [String:Any]()
            var error : NSError
            
            if streamError.domain == kCFStreamErrorDomainNetDB {
                userInfo[kCFGetAddrInfoFailureKey as String] = NSNumber(value: streamError.error).description
            }
            error = NSError(domain: kCFErrorDomainCFNetwork as String, code: Int(CFNetworkErrors.cfHostErrorUnknown.rawValue), userInfo: userInfo)
            self.stop()
            
            //notify about error and return
            callBack(false,error)
            if hostRef != nil{
                
            }
            
            
            return
        }
        
        //get the first IPv4 or IPv6 address
        var resolved = DarwinBoolean(false)
        let addresses = CFHostGetAddressing(hostRef!,&resolved)?.takeUnretainedValue() as? [NSData]
        
        if resolved.boolValue, let addresses = addresses {
            resolved = DarwinBoolean(false)
            for address in addresses{
                let anAddrPtr = address.bytes.bindMemory(to: sockaddr.self, capacity: address.length)
                if address.length >= MemoryLayout<sockaddr>.size, (anAddrPtr.pointee.sa_family == AF_INET || anAddrPtr.pointee.sa_family == AF_INET6){
                    resolved = DarwinBoolean(true)
                    self.hostAddress = address as Data
                    let sin = NSMutableData(bytes: address.bytes, length: address.length).mutableBytes.bindMemory(to: sockaddr_in.self, capacity: address.length)
                    var str = [CChar](repeating: 0, count: self.INET6_ADDRSTRLEN)
                    
                    inet_ntop(Int32(anAddrPtr.pointee.sa_family), &(sin.pointee.sin_addr), &str, socklen_t(self.INET6_ADDRSTRLEN));
                    self.hostAddressString = String(utf8String: str)!
                    break
                    
                }
                
            }
        }
        
        //we can stop host resolution now
        if hostRef != nil {
            //                CFRelease(hostRef);
        }
        
        //if an error occurred during resolution
        if !resolved.boolValue {
            //stop
            self.stop()
            callBack(false, NSError(domain: kCFErrorDomainCFNetwork as String, code: Int(CFNetworkErrors.cfHostErrorHostNotFound.rawValue), userInfo: nil))
            
            return
        }
        
        //set up socket
        var  err = 0
        switch self.hostAddressFamily {
        case sa_family_t(AF_INET):
            
            self.socketNum = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            if self.socketNum < 0{
                err = Int(errno)
            }
            break
            
        case sa_family_t(AF_INET6):
            self.socketNum = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
            if self.socketNum < 0{
                err = Int(errno)
            }
            break
            
        default:
            err = Int(EPROTONOSUPPORT)
            break
        }
        
        //couldnt setup socket
        if err != 0{
            //clean up so far
            self.stop()
            //            mainQueue.async {
            callBack(false, NSError(domain: NSPOSIXErrorDomain as String, code: err, userInfo: nil))
            //            }
            
            return
        }
        
        //set ttl on the socket
        if self.ttl != 0 {
            var ttlForSockOpt = u_char(self.ttl)
            setsockopt(self.socketNum, IPPROTO_IP, IP_TTL, &ttlForSockOpt, socklen_t(MemoryLayout<UInt>.size));
        }
        
        //we are ready now
        self.isReady = true
        //        mainQueue.async {
        callBack(true,nil)
        //        }
        self.isStopped = true
    }
    
    
}

extension Data{
    var bytes : UnsafeRawPointer{
        get{
            //            let bytes = [UInt8](self)
            //            return UnsafeRawPointer(bytes)
            return (self as NSData).bytes
        }
    }
}

