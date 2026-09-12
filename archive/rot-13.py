import sys

uppers = [char for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
lowers = [char for char in "abcdefghijklmnopqrstuvwxyz"]
alphabet = [uppers, lowers]
dictionary = dict()

for case in alphabet:
    for char in case:
        index = case.index(char)
        if index > 12:
            dictionary[char] = case[index-13]
        else:
            dictionary[char] = case[index+13]
                
if len(sys.argv) > 1:
    if sys.argv[1]==['-q']:
        pass
else:
    print("ROT-13 Encrypter & Decrypter\n")
    print("Rot13 or Rot-13 (short for rotate 13) is a simple letter substitution encryption scheme.\nIt works by replacing the current English letters in a message with those that are 13 positions ahead in the alphabet.\nFor example, the letter a is replaced by n, b by o. c by p. etc. Numbers and punctuation are not encoded.\n")
    print('You may find newsgroup postings that are rot-13 encoded. It is sometimes used to hide\noffensive material from accidental viewing (naughty jokes for example). Unless you choose to decode it, the message will\njust appear as a bunch of gibberish (such as "GBB ZNAL FRPERGF").\n')
    print("Rot-13 encoding can be used for other purposes as well. Jokes and discussions that give\naway the ending to a movie are sometimes encoded so that it cannot be read on accident. A major advantage of ROT13 over ROT(N)\nfor other N is that it is self-inverse, so the same code can be used for encoding and decoding.\n")

msg = input("Enter message to encrypt or decrypt:\n")
msg = [char for char in msg]
output = ""

for char in msg:
    if char in dictionary.keys():
        output+=dictionary[char]
    else:
        output+=char
    
print(f"\nOutput:\n{output}")