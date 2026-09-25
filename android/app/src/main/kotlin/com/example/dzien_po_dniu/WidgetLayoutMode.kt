package com.example.dzien_po_dniu

enum class WidgetLayoutMode {
    SMALL,
    MEDIUM,
    LARGE;

    companion object {
        fun fromSize(widthDp: Int, heightDp: Int): WidgetLayoutMode = when {
            widthDp >= 260 && heightDp >= 180 -> LARGE
            widthDp >= 160 && heightDp >= 105 -> MEDIUM
            else -> SMALL
        }
    }
}
