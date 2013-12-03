Postbin
=======

Mailgun's Postbin application @ http://bin.mailgun.net

Application Server: Heroku  
Database: Heroku Postgres  

To run locally (connects to production DB), run:

```ruby
gem install rack  
gem install bundle  
bundle  
rackup config.ru
```

##API
POST http://bin.mailgun.net/api/new  
Creates a new Postbin  

```
{
    "url": "http://bin.mailgun.net/b50299cc"
}
```

POST http://bin.mailgun.net/api/:id  
Stores data in the Postbin  

```
{
    "message": "Post received. Thanks!"
}
```

GET http://bin.mailgun.net/api/:id  
Returns bin contents in JSON

```
[
    {
        "id": 153,
        "params": "{\"recipient\":\"test@mailgunhq.com\",\"sender\":\"travis@mailgunhq.com\",\"stripped-text\":\"A POST!\",\"timestamp\":\"1358041467\"}",
        "created_at": 1385798101,
        "bin_id": 59
    }
]
```

DELETE http://bin.mailgun.net/api/:id  
Deletes a Postbin

```
{
    "message": "Bin id deleted"
}
```


##Web UI
GET http://bin.mailgun.net/  
Creates a new Postbin

GET http://bin.mailgun.net/:id  
Returns formatted HTML

##SDK Troubleshooting
POST http://bin.mailgun.net/:id/*  
Stores endpoint URL (anything in *), and authentication (pass obfuscated)  

##Utils
GET http://bin.mailgun.net/utils/stats   
Returns bin and item stats in JSON  

```
{
    "total_bins": 56,
    "total_items": 153,
    "total_rows": 209
}
```

GET http://bin.mailgun.net/utils/cleanup  
Deletes any bins older than 5 days