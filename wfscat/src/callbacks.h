#include <gtk/gtk.h>


void
on_MainWindow_destroy                  (GtkObject       *object,
                                        gpointer         user_data);

void
on_quit1_activate                      (GtkMenuItem     *menuitem,
                                        gpointer         user_data);

void
on_about1_activate                     (GtkMenuItem     *menuitem,
                                        gpointer         user_data);

void
on_FindTel_clicked                     (GtkButton       *button,
                                        gpointer         user_data);

void
on_FindHere_clicked                    (GtkButton       *button,
                                        gpointer         user_data);

void
on_Flip_clicked                        (GtkButton       *button,
                                        gpointer         user_data);

void
on_cb_stoprefreshing_toggled           (GtkToggleButton *togglebutton,
                                        gpointer         user_data);

void
on_GoOnAxis_clicked                    (GtkButton       *button,
                                        gpointer         user_data);

void
on_GoOffAxis_clicked                   (GtkButton       *button,
                                        gpointer         user_data);

void
on_Return_clicked                      (GtkButton       *button,
                                        gpointer         user_data);
