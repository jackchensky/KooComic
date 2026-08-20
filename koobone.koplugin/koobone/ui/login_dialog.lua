local CheckButton = require("ui/widget/checkbutton")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")

local LoginDialog = {}

function LoginDialog.show(options)
    options = options or {}
    local auth = assert(options.auth, "auth required")
    local settings = assert(options.settings, "settings required")
    local account = settings:account()
    local dialog, remember
    dialog = MultiInputDialog:new{
        title = options.title or "登录 KOOBONE",
        fields = {
            {
                text = account.email or "",
                hint = "邮箱",
            },
            {
                text = account.remember_password and account.password or "",
                hint = "密码",
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
                    text = "登录",
                    is_enter_default = true,
                    callback = function()
                        local fields = dialog:getFields()
                        local email, password = fields[1], fields[2]
                        local should_remember = remember.checked == true
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{ text = "正在登录……", timeout = 1 })
                        UIManager:scheduleIn(0.15, function()
                            local ok, result = auth:login(email, password, should_remember)
                            password = nil
                            if ok then
                                UIManager:show(InfoMessage:new{ text = "登录成功。", timeout = 1 })
                                if options.on_success then options.on_success(result) end
                            else
                                UIManager:show(InfoMessage:new{
                                    text = "登录失败：\n" .. tostring(result),
                                })
                            end
                        end)
                    end,
                },
            },
        },
    }
    remember = CheckButton:new{
        text = "记住密码（密码将保存在本机设置中）",
        checked = account.remember_password == true,
        parent = dialog,
    }
    dialog:addWidget(remember)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
    return dialog
end

return LoginDialog

