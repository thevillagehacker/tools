import requests

requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)

def format_text(title, item):
    cr='\r\n'
    section_break = cr + "-" * 20 + cr
    item=str(item)
    text = title + section_break + item + section_break
    return text
r = requests.get('https://thevillagehacker.com', verify=False)
print(format_text('r.status_code is: ',r.status_code))
print(format_text('r.text is: ',r.text))
print(format_text('r.headers is: ',r.headers))
print(format_text('r.cookies is: ',r.cookies))
print(format_text('r.url is: ',r.url))