const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

const { admin } = require("../shared/firebase");
const {
  normalizeWord,
  isValidVietnameseWord,
} = require("../shared/vietnameseDictionary");

const validateWordChainDictionary = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return;

    const game = after.minigames?.wordChain;
    if (!game) return;

    const pending = game.pendingWord;
    if (!pending) return;

    const prevPending = before?.minigames?.wordChain?.pendingWord;
    if (
      prevPending &&
      prevPending.word === pending.word &&
      prevPending.uid === pending.uid
    ) {
      return;
    }

    const rawWord = pending.word;
    const uid = pending.uid;
    const ref = event.data.after.ref;

    if (!rawWord || !uid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
      });
      return;
    }

    const word = normalizeWord(rawWord);

    if (game.status !== "playing") {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "not_playing",
      });
      return;
    }

    if (game.turnUid !== uid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "not_your_turn",
      });
      return;
    }

    const parts = word.split(" ");
    if (parts.length !== 2) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "format",
      });
      return;
    }

    const usedWords = (game.usedWords || []).map(normalizeWord);
    if (usedWords.includes(word)) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "used_word",
      });
      return;
    }

    const prevWord = game.currentWord || "";
    if (prevWord) {
      const prevLast = normalizeWord(prevWord).split(" ").pop();
      const first = parts[0];

      if (first !== prevLast) {
        await ref.update({
          "minigames.wordChain.pendingWord":
            admin.firestore.FieldValue.delete(),
          "minigames.wordChain.invalidReason": "chain_mismatch",
        });
        return;
      }
    }

    if (!isValidVietnameseWord(word)) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
        "minigames.wordChain.invalidReason": "dictionary",
      });
      return;
    }

    const participants = after.participants || [];
    const nextUid = participants.find((id) => id !== uid);

    if (!nextUid) {
      await ref.update({
        "minigames.wordChain.pendingWord":
          admin.firestore.FieldValue.delete(),
      });
      return;
    }

    await ref.update({
      "minigames.wordChain.currentWord": word,
      "minigames.wordChain.usedWords":
        admin.firestore.FieldValue.arrayUnion(word),
      "minigames.wordChain.turnUid": nextUid,
      "minigames.wordChain.remainingSeconds": 15,
      "minigames.wordChain.pendingWord":
        admin.firestore.FieldValue.delete(),
      "minigames.wordChain.invalidReason":
        admin.firestore.FieldValue.delete(),
      "minigames.wordChain.updatedAt":
        admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

module.exports = {
  validateWordChainDictionary,
};
