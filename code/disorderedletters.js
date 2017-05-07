var toss = function (letters) {
    var getRandomIntInclusive = function (min, max) {
        min = Math.ceil(min);
        max = Math.floor(max);
        return Math.floor(Math.random() * (max - min + 1)) + min;
    };
    var result = "";
    var letter = null;
    var length = letters.length;

    // pick one letter for the remaining 'letters add it to the result and
    // remove it from letters.
    for (var i = 0; i < length; i++) {
        letter = getRandomIntInclusive(0, letters.length - 1);
        result += letters[letter];
        letters = letters.substring(0, letter) + letters.substring(letter + 1, letters.length);
    }

    return result;
};

var wordToss = function (word) {
    if (word.length < 4)
        return word;

    // Keep the first and the last letter in place and only
    // suffle letter in between.
    var subWord = word.substring(1, word.length - 1);

    return word[0] + toss(subWord) + word[word.length - 1];
};

var allWords = function (input) {
    var reg = /[a-zA-ZçàèéùìòỳàâêîôŷûäëÿüïöÇÀÈÉÙÌÒỲÀÂÊÎÔŶÛÄËŸÜÏÖ]+/gi;
    var lastPosition = 0;
    var elem = reg.exec(input);
    if (elem === null)
        return input;

    var result = "";
    var hash = {};
    while (elem !== null) {
        result += input.substring(lastPosition, elem.index);
        if (hash[elem[0]] === undefined) {
            hash[elem[0]] = wordToss(elem[0]);
        }
        result += hash[elem[0]];
        lastPosition = elem.index + elem[0].length;
        elem = reg.exec(input);
    }

    return result + input.substring(lastPosition, input.length);
};

document.addEventListener("DOMContentLoaded", function(event) {
    document.getElementById('reveal').onclick = function () {
        var tmp = allWords(document.getElementById('source-text').value);
        document.getElementById('dump').innerHTML = tmp;
    };
});
