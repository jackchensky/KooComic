local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local InfoPanel = require("koobone.ui.info_panel")

local AccountUI = {}

function AccountUI.show(options)
    local settings = assert(options.settings, "settings required")
    local auth = assert(options.auth, "auth required")
    local account = settings:account()
    local status = auth:hasSession() and "已登录" or "未登录"
    local remembered = account.remember_password and "已开启" or "未开启"
    local body = table.concat({
        "状态：" .. status,
        "昵称：" .. tostring(account.nick or "—"),
        "邮箱：" .. tostring(account.email ~= "" and account.email or "—"),
        "记住密码：" .. remembered,
    }, "\n")
    local dialog
    dialog = InfoPanel:new{
        title = "账号管理",
        subtitle = "KOOBONE 连接状态",
        body = body,
        text_size = settings:ui().text_size,
        buttons = {
            {
                {
                    text = auth:hasSession() and "重新登录" or "登录",
                    callback = function()
                        dialog:close()
                        if options.on_login then options.on_login() end
                    end,
                },
            },
            {
                {
                    text = "清除已保存密码",
                    enabled = account.remember_password == true,
                    callback = function()
                        settings:clearPassword()
                        dialog:close()
                        UIManager:show(InfoMessage:new{ text = "已清除保存的密码。" })
                    end,
                },
            },
            {
                {
                    text = "退出账号",
                    enabled = auth:hasSession(),
                    callback = function()
                        UIManager:show(ConfirmBox:new{
                            text = "退出后将清除会话和已保存密码，但不会删除已下载漫画。",
                            cancel_text = "取消",
                            ok_text = "退出账号",
                            ok_callback = function()
                                auth:logout()
                                dialog:close()
                                UIManager:show(InfoMessage:new{ text = "已退出 KOOBONE 账号。" })
                                if options.on_logout then options.on_logout() end
                            end,
                        })
                    end,
                },
            },
            {
                {
                    text = "版本与设置",
                    callback = function()
                        dialog:close()
                        if options.on_settings then options.on_settings() end
                    end,
                },
                {
                    text = "关闭",
                    callback = function() dialog:close() end,
                },
            },
        },
    }
    UIManager:show(dialog)
    return dialog
end

return AccountUI
