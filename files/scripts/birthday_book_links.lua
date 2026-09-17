function RQ_RequestOpenCardLink(card_id,url)
    if card_id == nil or card_id == "" then
        return
    end

    if url == nil or url == "" then
        return
    end

    if
        string.sub(url,1,7) ~= "http://" and
        string.sub(url,1,8) ~= "https://"
    then
        GamePrint("Birthday Book: invalid link")
        return
    end

    if
        RQ_WriteBirthdayLinkRequest ~= nil and
        RQ_WriteBirthdayLinkRequest(card_id,url)
    then
        GamePrint("Opening birthday card link...")
    end
end
