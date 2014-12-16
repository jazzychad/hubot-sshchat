Robot   = require('hubot').Robot
Adapter = require('hubot').Adapter
TextMessage = require('hubot').TextMessage
Response = require('hubot').Response
util = require('util')

SSHConnection = require('ssh2')
conn = new SSHConnection()

class SSHChatAdapter extends Adapter

  send: (envelope, strings...) ->
    for string in strings
      strs = string.split "\n"
      for str in strs
        if envelope?.user?.room == "pm"
          @sshStream.write "/msg " + envelope.user.name + " " + str + "\r"
        else
          @sshStream.write str + "\r"

  reply: (envelope, strings...) ->
    for string in strings
      @send envelope, envelope.user.name + ": " + string

  run: ->
    self = @
    options =
      host: process.env.HUBOT_SSHCHAT_SERVER
      port: process.env.HUBOT_SSHCHAT_PORT
      username: process.env.HUBOT_SSHCHAT_USERNAME
      privateKey: require('fs').readFileSync(process.env.HUBOT_SSHCHAT_IDENTKEY)
    conn.connect options
    conn.on "ready", ->
      console.log "connected to ssh-chat!"
      conn.shell (err, stream) ->
        throw err if err
        self.sshStream = stream
        self.emit "connected"
        stream.write "/theme mono" + "\r"
        stream.on 'data', (data) ->
          data = data + ""
          #console.log("** raw data: " + data)
          data = data.substring 0, data.length - 2
          splitdata = data.split("\u001b[")
          newdata = []
          splitdata.forEach (v, k) ->
            if k == 0
              newdata.push v
            else
              newsection = v.split "m"
              newsection.shift()
              newdata.push(newsection.join "m")
          data = newdata.join ""
          #console.log("*** newdata: " + data)

          if data != "[" + options.username && data != "" && data != "\u001b[D\u001b[D\u001b[D\u001b[D\u001b[D\u001b[D\u001b"
            console.log(">>" + data + "<<")
            data = data.trim()
            if data.indexOf("[PM from ") == 0 or data.indexOf("[PM from ") == 1 # bell might be 0th char
              nick = data.substring(data.indexOf("[PM from ") + "[PM from ".length, data.indexOf("]"))
              #console.log("pm nick: " + nick)
              msg = data.substring(data.indexOf("]") + 1).trim()
              if msg.indexOf(options.username) != 0
                msg = options.username + ": " + msg
              #console.log("pm msg: " + msg)
              user = self.robot.brain.userForId nick, name: nick, reply_to: nick, room: "pm"
              self.receive new TextMessage(user, msg, 'pmId')
            else
              parts = data.split(" ")
              if parts.length >= 2
                if parts[0].indexOf(":") == -1
                  return
                author = parts[0].replace(":", "")
                parts.shift()
                msg = parts.join " "
                user = self.robot.brain.userForId author, name: author, room: "main"
                if author != options.username
                  self.receive new TextMessage(user, msg, 'messageId')
    

module.exports.use = (robot) ->
  new SSHChatAdapter robot
