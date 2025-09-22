![img](https://github.com/thevillagehacker/thevillagehacker/blob/master/Do%20Hacks%20to%20Secure.png)
# Bigfoot
Bigfoot is made for checking the subdomains which are vulnerable to takeover.

## Usage
To scan single target

```bash
./bigfoot.sh -d example.com
```

To scan multiple targets

```bash
./bigfoot.sh -f hosts.txt
```

## Note:-
As for now Bigfoot is only capable to check the domains which are using **heroku, Github, AWS, Bitbucket, Shopify, Tumblr, and wordpress** services.
