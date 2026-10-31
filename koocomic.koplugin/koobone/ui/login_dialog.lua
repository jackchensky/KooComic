local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")

local LoginDialog = {}

function LoginDialog.show(options)
    options = options or {}
    local auth = assert(options.auth, "auth required")
    local dialog
    dialog = MultiInputDialog:new{
        title = options.title or "连接 KOOBONE 账号",
        fields = {
            {
                description = "请在手机或电脑上登录 KOOBONE 网站，进入「设置 → 账号信息」，生成 API Key。\n\n" ..
                    "将生成的 API Key 输入下方，然后点击「连接」。\n\n" ..
                    "连接成功后，API Key 会保存在本机，通常无需重复输入。",
                text = "",
                hint = "API Key",
                text_type = "password",
            },
        },
        buttons = {
            {
                {
                    text = "取消",
                    id = "close",
                    callback = function() UIManager:close(dialog) end,
                },
                {
                    text = "连接",
                    is_enter_default = true,
                    callback = function()
                        local fields = dialog:getFields()
                        local key = fields[1]
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{ text = "正在连接……", timeout = 1 })
                        UIManager:scheduleIn(0.15, function()
                            local ok, result = auth:login(key)
                            key = nil
                            if ok then
                                UIManager:show(InfoMessage:new{ text = "连接成功。", timeout = 1 })
                                if options.on_success then options.on_success(result) end
                            else
                                UIManager:show(InfoMessage:new{
                                    text = "连接失败：\n" .. tostring(result),
                                })
                            end
                        end)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
    return dialog
end

return LoginDialog

