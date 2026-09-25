package com.example.dzien_po_dniu

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetLayoutModeTest {
    @Test fun smallWidgetUsesCompactContent() {
        assertEquals(WidgetLayoutMode.SMALL, WidgetLayoutMode.fromSize(110, 70))
    }

    @Test fun mediumWidgetShowsPrimaryContent() {
        assertEquals(WidgetLayoutMode.MEDIUM, WidgetLayoutMode.fromSize(180, 120))
    }

    @Test fun largeWidgetShowsExtendedContent() {
        assertEquals(WidgetLayoutMode.LARGE, WidgetLayoutMode.fromSize(300, 220))
    }
}
