import sys

class RomanNumeralConverter:
    def __init__(self):
        self.integer_to_roman = {
            1000: 'M',
            900: 'CM',
            500: 'D',
            400: 'CD',
            100: 'C',
            90: 'XC',
            50: 'L',
            40: 'XL',
            10: 'X',
            9: 'IX',
            5: 'V',
            4: 'IV',
            1: 'I'
        }

        self.roman_to_integer = {v: k for k, v in self.integer_to_roman.items()}

    def to_roman(self, number: int) -> str:
        result = ""
        for integer_step, numeral in self.integer_to_roman.items():
            while number >= integer_step:
                result += numeral
                number -= integer_step
        return result

    def to_integer(self, numeral: str) -> int:
        result = 0
        for i, n in enumerate(numeral):
            if i + 1 < len(numeral) and self.roman_to_integer[n] < self.roman_to_integer[numeral[i + 1]]:
                result -= self.roman_to_integer[n]
            else:
                result += self.roman_to_integer[n]
        return result

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 roman_numeral_converter.py [number|numeral] [i|r]")
        sys.exit()

    input_value, input_type = sys.argv[1:]
    converter = RomanNumeralConverter()
    if input_type == 'i':
        result = converter.to_roman(int(input_value))
        print(f"The Roman numeral equivalent of {input_value} is: {result}")
    elif input_type == 'r':
        result = converter.to_integer(input_value)
        print(f"The integer equivalent of {input_value} is: {result}")
    else:
        print("Invalid input type. Please specify 'i' for integer or 'r' for roman numeral.")
