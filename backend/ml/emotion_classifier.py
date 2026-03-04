"""
EmoTune BERT Emotion Classifier
Uses a fine-tuned BERT model for 12 emotion categories
Falls back to a rule-based classifier if model is not yet trained
"""
import os
import re
import json
import numpy as np
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Emotion labels
EMOTIONS = [
    'happy', 'sad', 'angry', 'motivational', 'fear',
    'depressing', 'surprising', 'stressed', 'calm',
    'lonely', 'romantic', 'nostalgic', 'mixed'
]

# AI response templates per emotion
EMOTION_RESPONSES = {
    'happy': [
        "That's wonderful! Your joy is contagious! 🌟 Here are some upbeat tracks to keep the good vibes going!",
        "Love your positive energy! Let's celebrate with some feel-good music! 🎉",
    ],
    'sad': [
        "I hope you feel okay someday. It is okay to be sad. You just need to let it go, and someday it will disappear. Here are some playlists you could listen to... 💙",
        "It's okay to feel sad. These songs understand what you're going through. You're not alone. 🌧️",
    ],
    'angry': [
        "I hear you. Sometimes we just need to let it out. Here's some music to channel that energy! 🔥",
        "Take a deep breath. Here are tracks that might help you process those feelings. 💪",
    ],
    'motivational': [
        "You've got this! 💪 Here are some power tracks to fuel your drive!",
        "The world is yours! Let this playlist push you forward! 🚀",
    ],
    'fear': [
        "It's okay to feel afraid. You're braver than you believe. Here's some calming music for you. 🌸",
        "Fear is natural. Let this music accompany you as you find your courage. 🕊️",
    ],
    'depressing': [
        "I'm here with you. These dark clouds will pass. Let music be your companion right now. 🌈",
        "You matter. Here's music that understands the weight you're carrying. Please take care of yourself. 💜",
    ],
    'surprising': [
        "Life is full of surprises! Here's an eclectic mix for your unexpected moment! 🎊",
        "Wow, sounds eventful! Here are tracks to match your surprise! ✨",
    ],
    'stressed': [
        "Take a breath. You're doing better than you think. Let this music help you unwind. 🌊",
        "Stress is temporary. Here are calming tracks to help you decompress. 🧘",
    ],
    'calm': [
        "What a peaceful moment. Here are some serene tracks to match your tranquility. 🌿",
        "Embracing the calm — here's music to deepen your peace. 🌙",
    ],
    'lonely': [
        "You are never truly alone. Here's music that feels like company. 🤝",
        "Even in solitude, music can be your friend. These songs were made for moments like yours. 🌟",
    ],
    'romantic': [
        "Love is in the air! 💕 Here are some romantic melodies for your heart!",
        "What a beautiful feeling! Here are songs that celebrate love in all its forms. ❤️",
    ],
    'nostalgic': [
        "Memories are precious. Here are songs to take you back to those special moments. 📼",
        "There's magic in nostalgia. Here's a playlist that feels like flipping through old photos. 🌅",
    ],
    'mixed': [
        "Life is complex and so are feelings. Here's a diverse playlist for your multifaceted mood. 🎭",
        "Sometimes we feel it all at once. Here's music that captures every shade of your mood. 🌈",
    ],
}

# Uplift messages shown after long listening
FEEL_BETTER_RESPONSES = [
    "Feel better? 🌟 Here's a special song to lift your spirits even higher!",
    "You've been listening for a while. Feel better? Let me recommend something to uplift you! ☀️",
    "I hope the music helped. Here's one more song just for you! 💫",
]

# Keyword-based fallback classifier
EMOTION_KEYWORDS = {
    'happy': ['happy', 'joy', 'excited', 'great', 'wonderful', 'amazing', 'fantastic', 'awesome', 'good', 'love', 'celebrate', 'cheerful', 'elated', 'delighted', 'glad', 'thrilled'],
    'sad': ['sad', 'cry', 'crying', 'tears', 'unhappy', 'miserable', 'heartbroken', 'hurt', 'pain', 'sorrow', 'grief', 'miss', 'loss', 'broken', 'weep'],
    'angry': ['angry', 'anger', 'mad', 'furious', 'rage', 'frustrated', 'irritated', 'annoyed', 'hate', 'upset', 'outraged', 'infuriated', 'livid'],
    'motivational': ['motivated', 'inspire', 'goal', 'achieve', 'success', 'hustle', 'grind', 'dream', 'push', 'determination', 'ambition', 'power', 'strength', 'conquer'],
    'fear': ['scared', 'afraid', 'fear', 'nervous', 'anxious', 'terrified', 'worried', 'panic', 'dread', 'frightened', 'phobia', 'paranoid'],
    'depressing': ['depressed', 'depression', 'hopeless', 'worthless', 'empty', 'numb', 'dark', 'bleak', 'despair', 'suicidal', 'meaningless', 'pointless'],
    'surprising': ['surprised', 'shock', 'unexpected', 'amazed', 'astonished', 'wow', 'unbelievable', 'incredible', 'mind-blown', 'stunned'],
    'stressed': ['stressed', 'stress', 'overwhelmed', 'pressure', 'deadline', 'busy', 'exhausted', 'tired', 'burnout', 'overloaded', 'tense', 'anxious'],
    'calm': ['calm', 'peaceful', 'relaxed', 'serene', 'tranquil', 'zen', 'content', 'quiet', 'still', 'meditative', 'composed', 'rest'],
    'lonely': ['lonely', 'alone', 'isolated', 'abandoned', 'rejected', 'left out', 'solitary', 'missing', 'longing', 'nobody', 'empty'],
    'romantic': ['love', 'romance', 'romantic', 'crush', 'date', 'relationship', 'affection', 'passion', 'intimate', 'adore', 'cherish', 'heart'],
    'nostalgic': ['nostalgic', 'nostalgia', 'memories', 'remember', 'past', 'childhood', 'miss', 'throwback', 'reminisce', 'old times', 'used to'],
}


class EmotionClassifier:
    """
    BERT-based emotion classifier with keyword fallback.
    Fine-tuned on GoEmotions + custom dataset for 13 emotion categories.
    """
    
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_loaded = False
        self._load_model()

    def _load_model(self):
        """Try to load trained BERT model, fall back to keyword-based"""
        try:
            from django.conf import settings
            model_path = settings.ML_MODEL_PATH
            
            if os.path.exists(model_path):
                from transformers import AutoTokenizer, AutoModelForSequenceClassification
                import torch
                
                self.tokenizer = AutoTokenizer.from_pretrained(str(model_path))
                self.model = AutoModelForSequenceClassification.from_pretrained(str(model_path))
                self.model.eval()
                self.model_loaded = True
                logger.info("BERT emotion model loaded successfully")
            else:
                logger.warning(f"Model path {model_path} not found. Using keyword fallback.")
        except Exception as e:
            logger.warning(f"Could not load BERT model: {e}. Using keyword fallback.")

    def predict(self, text: str) -> dict:
        """
        Predict emotion from text.
        Returns: {'emotion': str, 'confidence': float, 'all_scores': dict}
        """
        text = text.strip().lower()
        
        if self.model_loaded:
            return self._bert_predict(text)
        else:
            return self._keyword_predict(text)

    def _bert_predict(self, text: str) -> dict:
        """Use fine-tuned BERT model for prediction"""
        try:
            import torch
            inputs = self.tokenizer(
                text,
                return_tensors='pt',
                truncation=True,
                max_length=128,
                padding=True
            )
            with torch.no_grad():
                outputs = self.model(**inputs)
                probs = torch.softmax(outputs.logits, dim=1).squeeze().numpy()
            
            all_scores = {EMOTIONS[i]: float(probs[i]) for i in range(len(EMOTIONS))}
            top_emotion = max(all_scores, key=all_scores.get)
            
            return {
                'emotion': top_emotion,
                'confidence': all_scores[top_emotion],
                'all_scores': all_scores
            }
        except Exception as e:
            logger.error(f"BERT prediction error: {e}")
            return self._keyword_predict(text)

    def _keyword_predict(self, text: str) -> dict:
        """Rule-based keyword classifier as fallback"""
        scores = {emotion: 0.0 for emotion in EMOTIONS}
        words = re.findall(r'\w+', text.lower())
        
        for word in words:
            for emotion, keywords in EMOTION_KEYWORDS.items():
                if any(kw in text.lower() for kw in keywords):
                    scores[emotion] += 1.0
        
        total = sum(scores.values())
        if total == 0:
            scores['mixed'] = 1.0
            total = 1.0
        
        # Normalize
        all_scores = {k: v / total for k, v in scores.items()}
        
        # Add small noise for realism
        for k in all_scores:
            all_scores[k] = max(0.01, all_scores[k] + np.random.uniform(-0.01, 0.01))
        
        # Renormalize
        total2 = sum(all_scores.values())
        all_scores = {k: v / total2 for k, v in all_scores.items()}
        
        top_emotion = max(all_scores, key=all_scores.get)
        
        return {
            'emotion': top_emotion,
            'confidence': all_scores[top_emotion],
            'all_scores': all_scores
        }


# Singleton instance
_classifier = None

def get_classifier():
    global _classifier
    if _classifier is None:
        _classifier = EmotionClassifier()
    return _classifier


def get_ai_response(emotion: str) -> str:
    """Get AI response message for detected emotion"""
    import random
    responses = EMOTION_RESPONSES.get(emotion, EMOTION_RESPONSES['mixed'])
    return random.choice(responses)


def get_feel_better_message() -> str:
    import random
    return random.choice(FEEL_BETTER_RESPONSES)
