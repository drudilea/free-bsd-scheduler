from email.utils import parsedate
import re

# Open output text file
text_file = open("./out/dmesgOutputParsed.txt", "w")


with open('./out/dmesgOutput.txt') as f:
    content = f.read()
    # Elimina el timestamp del kernel y dejo la info necesaria en una nueva linea
    parsedContent = re.sub(r'(?:.*)(#&.*&#)', r"\1",
                           content, flags=re.MULTILINE)
    # Elimina el resto de logs del kernel
    parsedContent = re.sub(r'(^[^#&].*[^&#]$\n)', r"",
                           parsedContent, flags=re.MULTILINE)

    text_file.write(parsedContent)


# close file
text_file.close()
