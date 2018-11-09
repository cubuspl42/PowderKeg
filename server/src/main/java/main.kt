package server

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Thread.sleep
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketAddress
import kotlin.concurrent.thread

val mapper = jacksonObjectMapper()

data class ClientState(
        val x: Int,
        val y: Int,
        val z: Int,
        val imageSet: String
)

data class ClientUpdateMessage(
        val nick: String,
        val state: ClientState
)

data class ServerUpdateMessage(
        val clients: Map<String, ClientState>
)

class Server {
    private val clients = mutableMapOf<SocketAddress, ClientState>()

    @Synchronized
    fun handleClientUpdate(address: SocketAddress, message: ClientUpdateMessage) {
        clients[address] = message.state
    }

    @Synchronized
    fun buildServerUpdateMessage() =
            ServerUpdateMessage(clients.mapKeys {
                it.key.hashCode().toString()
            })

    @Synchronized
    fun removeClient(address: SocketAddress) {
        clients.remove(address)
    }
}

val server = Server()

fun clientReadThread(client: Socket) {
    val address = client.remoteSocketAddress
    try {
        BufferedReader(InputStreamReader(client.getInputStream())).useLines {
            it.forEach { line ->
                val message = mapper.readValue<ClientUpdateMessage>(line)
                server.handleClientUpdate(address, message)
            }
        }
    } catch (exception: Exception) {
        println("Exception in read thread ($address): $exception")
    }
}

fun clientWriteThread(client: Socket) {
    val address = client.remoteSocketAddress
    try {
        while (true) {
            val message = server.buildServerUpdateMessage()
            val messageString = mapper.writeValueAsString(message) + "\n"
            client.getOutputStream().write(messageString.toByteArray())
//            println("Writing to client: $message")
            sleep(16)
        }
    } catch (exception: Exception) {
        println("Exception in write thread ($address): $exception")
        server.removeClient(address)
    }
}

fun main(args: Array<String>) {
    ServerSocket(9999).use { server ->
        println("Server running on port ${server.localPort}")
        while (true) {
            server.accept().let { client ->
                println("Client connected : ${client.remoteSocketAddress}")
                thread { clientReadThread(client) }
                thread { clientWriteThread(client) }
                Unit
            }
        }
    }
}
