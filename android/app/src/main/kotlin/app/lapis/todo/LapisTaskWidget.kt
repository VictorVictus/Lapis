package app.lapis.todo

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import org.json.JSONArray

private data class TaskItemData(
    val title: String,
    val status: Int,
    val priority: Int,
    val category: String,
    val color: Int
)

class LapisTaskWidget : GlanceAppWidget() {
    override val stateDefinition: androidx.glance.state.GlanceStateDefinition<*>? = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val tasksJson = prefs.getString("tasks_json", null)
        val totalPending = prefs.getInt("total_pending", 0)

        val taskItems = if (tasksJson != null) {
            try {
                val arr = JSONArray(tasksJson)
                (0 until minOf(arr.length(), 5)).map { i ->
                    val obj = arr.getJSONObject(i)
                    val rawColor = obj.opt("color")
                    val parsedColor = when (rawColor) {
                        is Number -> rawColor.toInt()
                        is String -> (rawColor.toLong(16) and 0xFFFFFFFFL).toInt()
                        else -> 0xFF8E8E93.toInt()
                    }
                    TaskItemData(
                        title = obj.getString("title"),
                        status = obj.getInt("status"),
                        priority = obj.optInt("priority", 0),
                        category = obj.optString("category", ""),
                        color = parsedColor
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        } else {
            emptyList()
        }

        provideContent {
            Box(
                modifier = GlanceModifier.fillMaxSize()
                    .background(androidx.glance.unit.ColorProvider(Color(0xFF0D0D1A)))
                    .padding(12.dp),
                contentAlignment = Alignment.TopCenter
            ) {
                Column(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top
                ) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(bottom = 8.dp),
                        horizontalAlignment = Alignment.Horizontal.Start,
                        verticalAlignment = Alignment.Vertical.CenterVertically
                    ) {
                        Text(
                            text = "Today",
                            style = TextStyle(
                                color = androidx.glance.unit.ColorProvider(Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 18.sp
                            )
                        )
                        if (totalPending > 0) {
                            Text(
                                text = "  $totalPending",
                                style = TextStyle(
                                    color = androidx.glance.unit.ColorProvider(Color(0xFF30D158)),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp
                                )
                            )
                        }
                    }

                    if (taskItems.isEmpty()) {
                        Text(
                            text = "All caught up!",
                            modifier = GlanceModifier.padding(top = 16.dp),
                            style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(Color(0xFF8E8E93)),
                                fontSize = 14.sp
                            )
                        )
                    } else {
                        taskItems.forEach { item ->
                            TaskCard(item = item)
                        }
                    }
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun TaskCard(item: TaskItemData) {
    val priorityColor = when (item.priority) {
        3 -> Color(0xFFFF453A)
        2 -> Color(0xFFFFD60A)
        1 -> Color(0xFF30D158)
        else -> Color(0xFF3A3A3C)
    }
    val bgColor = if (item.status == 1) Color(0xFF1C1C2E) else Color(0xFF16161F)
    val titleColor = if (item.status == 1) Color(0xFFFFD60A) else Color.White

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 3.dp)
            .background(androidx.glance.unit.ColorProvider(bgColor)),
        horizontalAlignment = Alignment.Horizontal.Start,
        verticalAlignment = Alignment.Vertical.CenterVertically
    ) {
        Box(
            modifier = GlanceModifier
                .width(4.dp)
                .height(34.dp)
                .background(androidx.glance.unit.ColorProvider(priorityColor)),
            contentAlignment = Alignment.Center
        ) {}

        Column(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = item.title,
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(titleColor),
                    fontSize = 13.sp,
                    fontWeight = if (item.status == 1) FontWeight.Medium else FontWeight.Normal
                ),
                maxLines = 1
            )
            if (item.category.isNotEmpty()) {
                Text(
                    text = item.category,
                    style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(Color(item.color)),
                        fontSize = 10.sp
                    )
                )
            }
        }
    }
}

class LapisTaskWidgetReceiver : HomeWidgetGlanceWidgetReceiver<LapisTaskWidget>() {
    override val glanceAppWidget: LapisTaskWidget
        get() = LapisTaskWidget()
}
